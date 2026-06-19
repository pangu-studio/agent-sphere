#include "manager/oidc_client.h"
#include "manager/oidc_token_store.h"

#include <nlohmann/json.hpp>

#include <atomic>
#include <chrono>
#include <cstdint>
#include <cstring>
#include <functional>
#include <sstream>
#include <string>
#include <thread>
#include <vector>

#ifdef _WIN32
#define NOMINMAX
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <winsock2.h>
#include <ws2tcpip.h>
#include <bcrypt.h>
#include <winhttp.h>
#pragma comment(lib, "ws2_32.lib")
#pragma comment(lib, "bcrypt.lib")
#pragma comment(lib, "winhttp.lib")
#else
#include <Security/Security.h> // arc4random_buf on Apple
#include <arpa/inet.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <unistd.h>
#if !defined(__APPLE__)
#include <fcntl.h>
#endif
#endif

namespace manager {

using json = nlohmann::json;

// ── Random bytes ─────────────────────────────────────────────────────────────

static void RandomBytes(uint8_t *buf, size_t len) {
#ifdef _WIN32
  BCryptGenRandom(nullptr, buf, static_cast<ULONG>(len),
                  BCRYPT_USE_SYSTEM_PREFERRED_RNG);
#elif defined(__APPLE__)
  arc4random_buf(buf, len);
#else
  int fd = open("/dev/urandom", O_RDONLY);
  if (fd >= 0) {
    size_t got = 0;
    while (got < len) {
      ssize_t r = read(fd, buf + got, len - got);
      if (r <= 0)
        break;
      got += static_cast<size_t>(r);
    }
    close(fd);
  }
#endif
}

static std::string RandomHex(size_t bytes) {
  std::vector<uint8_t> buf(bytes);
  RandomBytes(buf.data(), bytes);
  static const char *hex = "0123456789abcdef";
  std::string out;
  out.reserve(bytes * 2);
  for (uint8_t b : buf) {
    out += hex[b >> 4];
    out += hex[b & 0xf];
  }
  return out;
}

// ── URL decode ───────────────────────────────────────────────────────────────

static int HexDigit(char c) {
  if (c >= '0' && c <= '9') return c - '0';
  if (c >= 'a' && c <= 'f') return c - 'a' + 10;
  if (c >= 'A' && c <= 'F') return c - 'A' + 10;
  return -1;
}

static std::string UrlDecode(const std::string &s) {
  std::string out;
  out.reserve(s.size());
  for (size_t i = 0; i < s.size(); ++i) {
    if (s[i] == '%' && i + 2 < s.size()) {
      int hi = HexDigit(s[i + 1]);
      int lo = HexDigit(s[i + 2]);
      if (hi >= 0 && lo >= 0) {
        out += static_cast<char>((hi << 4) | lo);
        i += 2;
        continue;
      }
    } else if (s[i] == '+') {
      out += ' ';
      continue;
    }
    out += s[i];
  }
  return out;
}

// ── Parse query string ───────────────────────────────────────────────────────

static std::string QueryParam(const std::string &query,
                              const std::string &key) {
  // query may start with '?'
  size_t start = (query.empty() || query[0] != '?') ? 0 : 1;
  std::string search = key + "=";
  size_t pos = query.find(search, start);
  while (pos != std::string::npos) {
    if (pos == start || query[pos - 1] == '&') {
      size_t end = query.find('&', pos + search.size());
      std::string raw = query.substr(
          pos + search.size(),
          end == std::string::npos ? std::string::npos : end - pos - search.size());
      return UrlDecode(raw);
    }
    pos = query.find(search, pos + 1);
  }
  return {};
}

// ── Base64url decode ─────────────────────────────────────────────────────────

static std::vector<uint8_t> Base64UrlDecode(const std::string &s) {
  // Convert base64url → base64
  std::string b64 = s;
  for (char &c : b64) {
    if (c == '-') c = '+';
    else if (c == '_') c = '/';
  }
  // Add padding
  while (b64.size() % 4) b64 += '=';

  static const int8_t kTable[256] = {
      -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
      -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
      -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,62,-1,-1,-1,63,
      52,53,54,55,56,57,58,59,60,61,-1,-1,-1,-1,-1,-1,
      -1, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9,10,11,12,13,14,
      15,16,17,18,19,20,21,22,23,24,25,-1,-1,-1,-1,-1,
      -1,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,
      41,42,43,44,45,46,47,48,49,50,51,-1,-1,-1,-1,-1,
      -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
      -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
      -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
      -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
      -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
      -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
      -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
      -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
  };

  std::vector<uint8_t> out;
  out.reserve(b64.size() * 3 / 4);
  for (size_t i = 0; i + 3 < b64.size(); i += 4) {
    int8_t a = kTable[static_cast<uint8_t>(b64[i])];
    int8_t b = kTable[static_cast<uint8_t>(b64[i+1])];
    int8_t c = kTable[static_cast<uint8_t>(b64[i+2])];
    int8_t d = kTable[static_cast<uint8_t>(b64[i+3])];
    if (a < 0 || b < 0) break;
    out.push_back(static_cast<uint8_t>((a << 2) | (b >> 4)));
    if (c >= 0) out.push_back(static_cast<uint8_t>(((b & 0xf) << 4) | (c >> 2)));
    if (d >= 0) out.push_back(static_cast<uint8_t>(((c & 0x3) << 6) | d));
  }
  return out;
}

// ── Parse JWT payload for user info ──────────────────────────────────────────

static void ParseJwtUserInfo(const std::string &token, OidcToken *out) {
  // JWT = header.payload.signature — extract the middle segment
  size_t dot1 = token.find('.');
  if (dot1 == std::string::npos) return;
  size_t dot2 = token.find('.', dot1 + 1);
  if (dot2 == std::string::npos) return;

  std::string payload_b64 = token.substr(dot1 + 1, dot2 - dot1 - 1);
  auto payload_bytes = Base64UrlDecode(payload_b64);
  if (payload_bytes.empty()) return;

  std::string payload_str(reinterpret_cast<const char *>(payload_bytes.data()),
                          payload_bytes.size());
  try {
    auto j = json::parse(payload_str);
    std::string name = j.value("name", "");
    std::string preferred_username = j.value("preferred_username", "");
    std::string sub = j.value("sub", "");
    std::string email = j.value("email", "");

    // displayName: name > preferred_username > sub
    if (!name.empty()) out->display_name = name;
    else if (!preferred_username.empty()) out->display_name = preferred_username;
    else out->display_name = sub;

    if (!email.empty()) out->email = email;
  } catch (...) {}
}

// ── POSIX / WinSock socket wrappers ──────────────────────────────────────────

#ifdef _WIN32
using sock_t = SOCKET;
static const sock_t kInvalidSock = INVALID_SOCKET;
static void CloseSock(sock_t s) { closesocket(s); }
#else
using sock_t = int;
static const sock_t kInvalidSock = -1;
static void CloseSock(sock_t s) { close(s); }
#endif

// Bind a server socket on 127.0.0.1:0, return fd and actual port.
static sock_t BindLocalServer(uint16_t *out_port) {
#ifdef _WIN32
  WSADATA wsa{};
  WSAStartup(MAKEWORD(2, 2), &wsa);
#endif
  sock_t fd = socket(AF_INET, SOCK_STREAM, 0);
  if (fd == kInvalidSock)
    return kInvalidSock;

  int reuse = 1;
  setsockopt(fd, SOL_SOCKET, SO_REUSEADDR,
             reinterpret_cast<const char *>(&reuse), sizeof(reuse));

  sockaddr_in addr{};
  addr.sin_family = AF_INET;
  addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
  addr.sin_port = 0;

  if (bind(fd, reinterpret_cast<sockaddr *>(&addr), sizeof(addr)) != 0) {
    CloseSock(fd);
    return kInvalidSock;
  }
  if (listen(fd, 1) != 0) {
    CloseSock(fd);
    return kInvalidSock;
  }

  sockaddr_in actual{};
  socklen_t len = sizeof(actual);
  getsockname(fd, reinterpret_cast<sockaddr *>(&actual), &len);
  *out_port = ntohs(actual.sin_port);
  return fd;
}

// ── HTTP POST (Windows WinHTTP) ───────────────────────────────────────────────

#ifdef _WIN32
struct HttpResult {
  int status = 0;
  std::string body;
  std::string error;
};

// Parse scheme://host[:port]/path from a URL string.
static bool ParseUrl(const std::string &url, bool *out_https,
                     std::string *out_host, INTERNET_PORT *out_port,
                     std::string *out_path) {
  auto after_scheme = url.find("://");
  if (after_scheme == std::string::npos) return false;
  std::string scheme = url.substr(0, after_scheme);
  *out_https = (scheme == "https");
  *out_port = *out_https ? INTERNET_DEFAULT_HTTPS_PORT
                         : INTERNET_DEFAULT_HTTP_PORT;

  std::string rest = url.substr(after_scheme + 3);
  auto slash = rest.find('/');
  std::string host_port =
      (slash == std::string::npos) ? rest : rest.substr(0, slash);
  *out_path = (slash == std::string::npos) ? "/" : rest.substr(slash);

  auto colon = host_port.rfind(':');
  if (colon != std::string::npos) {
    *out_host = host_port.substr(0, colon);
    *out_port =
        static_cast<INTERNET_PORT>(std::stoi(host_port.substr(colon + 1)));
  } else {
    *out_host = host_port;
  }
  return true;
}

static HttpResult HttpPost(const std::string &url,
                           const std::string &content_type,
                           const std::string &body) {
  HttpResult result;
  bool is_https = true;
  std::string host, path;
  INTERNET_PORT port = INTERNET_DEFAULT_HTTPS_PORT;
  if (!ParseUrl(url, &is_https, &host, &port, &path)) {
    result.error = "invalid url";
    return result;
  }

  std::wstring whost(host.begin(), host.end());
  std::wstring wpath(path.begin(), path.end());
  std::wstring wctype(content_type.begin(), content_type.end());

  HINTERNET session =
      WinHttpOpen(L"AgentSphere/1.0", WINHTTP_ACCESS_TYPE_DEFAULT_PROXY,
                  WINHTTP_NO_PROXY_NAME, WINHTTP_NO_PROXY_BYPASS, 0);
  if (!session) { result.error = "WinHttpOpen failed"; return result; }

  HINTERNET conn = WinHttpConnect(session, whost.c_str(), port, 0);
  if (!conn) {
    WinHttpCloseHandle(session);
    result.error = "WinHttpConnect failed";
    return result;
  }

  DWORD flags = is_https ? WINHTTP_FLAG_SECURE : 0;
  HINTERNET req = WinHttpOpenRequest(conn, L"POST", wpath.c_str(), nullptr,
                                     WINHTTP_NO_REFERER,
                                     WINHTTP_DEFAULT_ACCEPT_TYPES, flags);
  if (!req) {
    WinHttpCloseHandle(conn);
    WinHttpCloseHandle(session);
    result.error = "WinHttpOpenRequest failed";
    return result;
  }

  std::wstring headers = L"Content-Type: " + wctype + L"\r\n";
  bool ok =
      WinHttpSendRequest(req, headers.c_str(), static_cast<DWORD>(-1L),
                         const_cast<char *>(body.data()),
                         static_cast<DWORD>(body.size()),
                         static_cast<DWORD>(body.size()), 0) != FALSE &&
      WinHttpReceiveResponse(req, nullptr) != FALSE;

  if (ok) {
    DWORD status = 0;
    DWORD sz = sizeof(status);
    WinHttpQueryHeaders(req,
                        WINHTTP_QUERY_STATUS_CODE | WINHTTP_QUERY_FLAG_NUMBER,
                        nullptr, &status, &sz, nullptr);
    result.status = static_cast<int>(status);
    if (status < 200 || status >= 300) {
      result.error = "HTTP " + std::to_string(status);
    }
    // Read body regardless of status (error messages)
    DWORD avail = 0;
    while (WinHttpQueryDataAvailable(req, &avail) && avail > 0) {
      std::string chunk(avail, '\0');
      DWORD read = 0;
      WinHttpReadData(req, chunk.data(), avail, &read);
      result.body.append(chunk.data(), read);
    }
  } else {
    result.error = "WinHttpSendRequest/ReceiveResponse failed";
  }

  WinHttpCloseHandle(req);
  WinHttpCloseHandle(conn);
  WinHttpCloseHandle(session);
  return result;
}

static HttpResult HttpGet(const std::string &url,
                          const std::string &auth_header = "") {
  HttpResult result;
  bool is_https = true;
  std::string host, path;
  INTERNET_PORT port = INTERNET_DEFAULT_HTTPS_PORT;
  if (!ParseUrl(url, &is_https, &host, &port, &path)) {
    result.error = "invalid url";
    return result;
  }

  std::wstring whost(host.begin(), host.end());
  std::wstring wpath(path.begin(), path.end());

  HINTERNET session =
      WinHttpOpen(L"AgentSphere/1.0", WINHTTP_ACCESS_TYPE_DEFAULT_PROXY,
                  WINHTTP_NO_PROXY_NAME, WINHTTP_NO_PROXY_BYPASS, 0);
  if (!session) { result.error = "WinHttpOpen failed"; return result; }

  HINTERNET conn = WinHttpConnect(session, whost.c_str(), port, 0);
  if (!conn) {
    WinHttpCloseHandle(session);
    result.error = "WinHttpConnect failed";
    return result;
  }

  DWORD flags = is_https ? WINHTTP_FLAG_SECURE : 0;
  HINTERNET req = WinHttpOpenRequest(conn, L"GET", wpath.c_str(), nullptr,
                                     WINHTTP_NO_REFERER,
                                     WINHTTP_DEFAULT_ACCEPT_TYPES, flags);
  if (!req) {
    WinHttpCloseHandle(conn);
    WinHttpCloseHandle(session);
    result.error = "WinHttpOpenRequest failed";
    return result;
  }

  std::wstring headers;
  if (!auth_header.empty()) {
    std::wstring wauth(auth_header.begin(), auth_header.end());
    headers = wauth + L"\r\n";
  }

  bool ok =
      WinHttpSendRequest(req,
                         headers.empty() ? WINHTTP_NO_ADDITIONAL_HEADERS
                                         : headers.c_str(),
                         headers.empty() ? 0 : static_cast<DWORD>(-1L),
                         WINHTTP_NO_REQUEST_DATA, 0, 0, 0) != FALSE &&
      WinHttpReceiveResponse(req, nullptr) != FALSE;

  if (ok) {
    DWORD status = 0;
    DWORD sz = sizeof(status);
    WinHttpQueryHeaders(req,
                        WINHTTP_QUERY_STATUS_CODE | WINHTTP_QUERY_FLAG_NUMBER,
                        nullptr, &status, &sz, nullptr);
    result.status = static_cast<int>(status);
    if (status < 200 || status >= 300) {
      result.error = "HTTP " + std::to_string(status);
    }
    DWORD avail = 0;
    while (WinHttpQueryDataAvailable(req, &avail) && avail > 0) {
      std::string chunk(avail, '\0');
      DWORD read = 0;
      WinHttpReadData(req, chunk.data(), avail, &read);
      result.body.append(chunk.data(), read);
    }
  } else {
    result.error = "WinHttpSendRequest/ReceiveResponse failed";
  }

  WinHttpCloseHandle(req);
  WinHttpCloseHandle(conn);
  WinHttpCloseHandle(session);
  return result;
}

#else
// macOS: use NSURLSession via a thin C wrapper.
extern bool OidcHttpGet_Mac(const std::string &url, std::string *body,
                            std::string *error);
struct HttpResult {
  int status = 200;
  std::string body;
  std::string error;
};
static HttpResult HttpGet(const std::string &url,
                          const std::string & = "") {
  HttpResult r;
  OidcHttpGet_Mac(url, &r.body, &r.error);
  return r;
}
static HttpResult HttpPost(const std::string &, const std::string &,
                           const std::string &) {
  HttpResult r;
  r.error = "HttpPost not implemented on this platform";
  return r;
}
#endif

// ── Trim trailing slash ───────────────────────────────────────────────────────

static std::string TrimSlash(const std::string &s) {
  size_t end = s.size();
  while (end > 0 && s[end - 1] == '/') --end;
  return s.substr(0, end);
}

// ── OidcFetchUserInfo ─────────────────────────────────────────────────────────

bool OidcFetchUserInfo(const std::string &cloud_url,
                       const std::string &access_token, OidcToken *out_token,
                       std::string *error) {
  if (cloud_url.empty() || access_token.empty()) {
    *error = "cloud_url or access_token is empty";
    return false;
  }
  std::string url = TrimSlash(cloud_url) + "/api/auth/me";
  std::string auth_header = "Authorization: Bearer " + access_token;
  auto result = HttpGet(url, auth_header);
  if (!result.error.empty()) {
    *error = "/api/auth/me request failed: " + result.error;
    return false;
  }
  try {
    auto j = json::parse(result.body);
    std::string name = j.value("name", "");
    std::string preferred_username = j.value("preferred_username", "");
    std::string sub = j.value("sub", "");
    std::string email = j.value("email", "");

    if (!name.empty()) out_token->display_name = name;
    else if (!preferred_username.empty()) out_token->display_name = preferred_username;
    else out_token->display_name = sub;

    if (!email.empty()) out_token->email = email;
  } catch (...) {
    *error = "failed to parse /api/auth/me response";
    return false;
  }
  return true;
}

// ── OidcLogin ────────────────────────────────────────────────────────────────

bool OidcLogin(const OidcConfig &config,
               std::function<void(const std::string &url)> open_url,
               OidcToken *out_token, std::string *error, int timeout_seconds) {
  if (config.cloud_url.empty()) {
    *error = "cloud_url is not configured";
    return false;
  }

  // 1. Generate state nonce.
  const std::string state = RandomHex(16);

  // 2. Bind local callback server.
  uint16_t port = 0;
  sock_t server_fd = BindLocalServer(&port);
  if (server_fd == kInvalidSock) {
    *error = "failed to bind local callback server";
    return false;
  }

  // 3. Build redirect_uri.
  const std::string redirect_uri =
      "http://127.0.0.1:" + std::to_string(port) + "/callback";

  // 4. POST /api/auth/start
  const std::string start_url = TrimSlash(config.cloud_url) + "/api/auth/start";
  json start_body;
  start_body["oidc_issuer"] = config.oidc_issuer;
  start_body["app_redirect_uri"] = redirect_uri;

  auto start_result = HttpPost(start_url, "application/json", start_body.dump());
  if (!start_result.error.empty()) {
    CloseSock(server_fd);
    *error = "/api/auth/start request failed: " + start_result.error;
    return false;
  }

  std::string browser_url;
  std::string server_state;
  try {
    auto j = json::parse(start_result.body);
    browser_url = j.value("browser_url", "");
    server_state = j.value("state", "");
  } catch (...) {}

  if (browser_url.empty()) {
    CloseSock(server_fd);
    *error = "/api/auth/start returned no browser_url";
    return false;
  }

  // 5. Open browser (caller-provided).
  open_url(browser_url);

  // 6. Wait for callback with timeout.
  std::string received_token, received_state;
  std::atomic<bool> done{false};
  std::atomic<bool> timed_out{false};

  // Watchdog thread closes server_fd after timeout_seconds.
  std::thread watchdog([&]() {
    for (int i = 0; i < timeout_seconds * 10 && !done.load(); ++i) {
      std::this_thread::sleep_for(std::chrono::milliseconds(100));
    }
    if (!done.load()) {
      timed_out = true;
      CloseSock(server_fd);
    }
  });

  // Accept loop: read one HTTP request.
  sock_t client_fd = accept(server_fd, nullptr, nullptr);
  done = true;
  watchdog.join();

  if (client_fd == kInvalidSock) {
    if (timed_out) {
      *error = "login timed out after " + std::to_string(timeout_seconds) + "s";
    } else {
      *error = "callback server accept failed";
    }
    return false;
  }
  CloseSock(server_fd);

  // Read request line (up to 4 KB).
  std::string request;
  request.resize(4096);
  int n = static_cast<int>(recv(client_fd, const_cast<char *>(request.data()),
                                static_cast<int>(request.size()) - 1, 0));
  if (n > 0)
    request.resize(n);
  else
    request.clear();

  // Send a minimal HTML response.
  const char *html_response = "HTTP/1.1 200 OK\r\n"
                              "Content-Type: text/html; charset=utf-8\r\n"
                              "Connection: close\r\n"
                              "\r\n"
                              "<!DOCTYPE html><html><body>"
                              "<h2>登录成功 — 您可以关闭此选项卡。</h2>"
                              "</body></html>\r\n";
  send(client_fd, html_response, static_cast<int>(strlen(html_response)), 0);
  CloseSock(client_fd);

  // Parse query string from request line: "GET /callback?token=xxx&state=yyy HTTP/1.1"
  auto query_start = request.find('?');
  auto query_end =
      request.find(' ', query_start != std::string::npos ? query_start : 0);
  std::string query;
  if (query_start != std::string::npos && query_end != std::string::npos) {
    query = request.substr(query_start, query_end - query_start);
  }

  received_token = QueryParam(query, "token");
  received_state = QueryParam(query, "state");

  // Validate state (use server_state if provided, otherwise our local state)
  const std::string &expected_state =
      server_state.empty() ? state : server_state;
  if (!expected_state.empty() && received_state != expected_state) {
    *error = "state mismatch — possible CSRF";
    return false;
  }
  if (received_token.empty()) {
    std::string err_param = QueryParam(query, "error");
    *error = err_param.empty() ? "no token in callback"
                               : "auth error: " + err_param;
    return false;
  }

  out_token->access_token = received_token;
  out_token->refresh_token = QueryParam(query, "refresh_token");
  std::string expires_in_str = QueryParam(query, "expires_in");
  if (!expires_in_str.empty()) {
    try {
      int64_t expires_in = std::stoll(expires_in_str);
      if (expires_in > 0) {
        out_token->expires_at =
            std::chrono::duration_cast<std::chrono::seconds>(
                std::chrono::system_clock::now().time_since_epoch())
                .count() +
            expires_in;
      }
    } catch (...) {}
  }

  // Parse user info from JWT payload (offline fallback)
  ParseJwtUserInfo(received_token, out_token);

  return true;
}

// ── OidcNeedsRefresh ─────────────────────────────────────────────────────────

bool OidcNeedsRefresh(const OidcToken &token) {
  if (token.expires_at == 0)
    return false;
  auto now = std::chrono::duration_cast<std::chrono::seconds>(
                 std::chrono::system_clock::now().time_since_epoch())
                 .count();
  return now >= token.expires_at - 300; // 5-minute buffer
}

} // namespace manager