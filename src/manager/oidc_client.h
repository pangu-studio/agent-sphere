#pragma once

#include <functional>
#include <string>

namespace manager {

struct OidcToken;

struct OidcConfig {
  // Base URL of the AgentSphere cloud backend (not the IAM provider directly).
  // The cloud backend proxies the OIDC flow and hides client_secret.
  // Example: "https://my-agent-sphere.pangustudio.com"
  std::string cloud_url;
  // OIDC issuer URL forwarded to the cloud backend (e.g. Keycloak realm URL).
  std::string oidc_issuer;
};

// Initiate login:
//   1. Binds a temporary HTTP server on 127.0.0.1 (random port).
//   2. POST {cloud_url}/api/auth/start {"oidc_issuer":..., "app_redirect_uri":...}
//      which returns {"browser_url":"...","state":"..."}.
//   3. Invokes open_url(browser_url) so the caller can open the browser.
//   4. Waits (up to timeout_seconds) for the cloud to redirect back with
//      ?token=...&state=... to the local callback server.
//   5. Validates state, parses JWT user info, writes out_token, closes the server.
//
// open_url is called on the calling thread before blocking; use it to
// open the system browser (ShellExecute on Windows).
// Returns true on success; sets *error on failure.
bool OidcLogin(const OidcConfig &config,
               std::function<void(const std::string &url)> open_url,
               OidcToken *out_token, std::string *error,
               int timeout_seconds = 120);

// Fetch user info from {cloud_url}/api/auth/me using the stored access token.
// On success fills out_token->display_name / email and returns true.
bool OidcFetchUserInfo(const std::string &cloud_url,
                       const std::string &access_token, OidcToken *out_token,
                       std::string *error);

// Returns true if the token expires within the next 5 minutes
// (or has already expired). Returns false if expires_at == 0 (unknown).
bool OidcNeedsRefresh(const OidcToken &token);

} // namespace manager