// Portions adapted from Starbox (GPL v3)
import AppKit
import Foundation
import Security

// MARK: - OidcService

/// 管理 AgentSphere 云端 OIDC 认证。
///
/// 登录流程（本地 HTTP server 方案，类似 VS Code / GitHub CLI）：
///   1. 本地绑定 127.0.0.1:{随机端口}，构造 redirect_uri
///   2. POST {cloudUrl}/api/auth/start {"oidc_issuer":"...", "app_redirect_uri":"http://127.0.0.1:{port}/callback"}
///      ← {"browser_url":"...","state":"..."}
///   3. 打开系统浏览器，用户在 IAM 完成登录
///   4. 服务端完成 token 换取后 302 → http://127.0.0.1:{port}/callback?token=xxx&state=yyy
///   5. 本地 server 收到请求，校验 state，存 Keychain
@MainActor
final class OidcService: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var loginError: String?

    private(set) var accessToken: String?
    private(set) var userInfo: OidcUserInfo?

    // MARK: - Public API

    /// 启动时调用，从 Keychain 恢复已登录状态
    func loadStoredToken(oidcIssuer: String = "") {
        guard let stored = KeychainToken.load() else { return }
        accessToken = stored.accessToken
        isAuthenticated = true

        if let cached = stored.userInfo {
            userInfo = cached
        } else {
            // 旧版本 Keychain 没有 userInfo，先用 JWT 解析兜底，再异步从 server 拉取
            userInfo = OidcLoginFlow.parseJwtUserInfo(token: stored.accessToken)
        }
    }

    /// 登录后或恢复登录后，异步从 server 刷新用户信息并缓存到 Keychain
    func refreshUserInfo(cloudUrl: String) {
        guard let token = accessToken, !cloudUrl.isEmpty else { return }
        Task {
            do {
                let info = try await OidcLoginFlow.fetchMeFromServer(
                    cloudUrl: cloudUrl, token: token)
                NSLog("[OidcService] refreshUserInfo ok: name=%@", info.name ?? "(nil)")
                await MainActor.run { self.userInfo = info }
                if let stored = KeychainToken.load() {
                    KeychainToken.save(
                        KeychainToken(
                            accessToken: stored.accessToken,
                            refreshToken: stored.refreshToken,
                            expiresAt: stored.expiresAt,
                            userInfo: info
                        ))
                }
            } catch {
                NSLog("[OidcService] refreshUserInfo failed: %@", error.localizedDescription)
            }
        }
    }

    /// 返回当前有效的 access_token
    func validToken() -> String? {
        guard isAuthenticated, let tok = accessToken else { return nil }
        return tok
    }

    /// 发起登录流程。在 SwiftUI 按钮 action 中调用。
    func login(cloudUrl: String, oidcIssuer: String) {
        guard !isLoading else { return }
        isLoading = true
        loginError = nil

        Task.detached(priority: .userInitiated) { [weak self] in
            do {
                let pair = try await OidcLoginFlow.run(
                    cloudUrl: cloudUrl,
                    oidcIssuer: oidcIssuer,
                    openURL: { url in
                        Task { @MainActor in NSWorkspace.shared.open(url) }
                    }
                )
                // 从 server 获取用户信息
                let userInfo = try? await OidcLoginFlow.fetchMeFromServer(
                    cloudUrl: cloudUrl, token: pair.accessToken
                )
                let token = KeychainToken(
                    accessToken: pair.accessToken,
                    refreshToken: pair.refreshToken,
                    expiresAt: pair.expiresIn > 0
                        ? Int64(Date().timeIntervalSince1970) + pair.expiresIn : nil,
                    userInfo: userInfo
                )
                KeychainToken.save(token)
                await MainActor.run {
                    self?.accessToken = pair.accessToken
                    self?.userInfo = pair.userInfo
                    self?.isAuthenticated = true
                    self?.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self?.loginError = error.localizedDescription
                    self?.isLoading = false
                }
            }
        }
    }

    /// 登出：清除 Keychain，回到登录页
    func logout() {
        KeychainToken.clear()
        accessToken = nil
        userInfo = nil
        isAuthenticated = false
        loginError = nil
    }
}

// MARK: - 登录流程

private enum OidcLoginFlow {
    static func run(
        cloudUrl: String,
        oidcIssuer: String,
        openURL: @escaping (URL) -> Void,
        timeoutSeconds: Int = 120
    ) async throws -> TokenPair {
        let base = cloudUrl.trimmingCharacters(in: .init(charactersIn: "/"))

        // 1. 绑定本地回调 server，获取随机端口
        let server = try LocalCallbackServer()
        let redirectUri = "http://127.0.0.1:\(server.port)/callback"

        // 2. POST /api/auth/start
        guard let startURL = URL(string: base + "/api/auth/start") else {
            throw OidcError.invalidUrl(base + "/api/auth/start")
        }
        var startReq = URLRequest(url: startURL)
        startReq.httpMethod = "POST"
        startReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
        startReq.httpBody = try JSONEncoder().encode(
            StartRequest(oidc_issuer: oidcIssuer, app_redirect_uri: redirectUri)
        )
        let (startData, startResp) = try await URLSession.shared.data(for: startReq)
        if let http = startResp as? HTTPURLResponse, http.statusCode < 200 || http.statusCode >= 300
        {
            throw OidcError.httpError(http.statusCode)
        }
        let startResult = try JSONDecoder().decode(StartResponse.self, from: startData)

        // 3. 打开浏览器
        guard let browserURL = URL(string: startResult.browser_url) else {
            throw OidcError.invalidUrl(startResult.browser_url)
        }
        openURL(browserURL)

        // 4. 等待回调（带超时）
        let query = try await withThrowingTaskGroup(of: String.self) { group in
            group.addTask {
                try await server.waitForCallback()
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeoutSeconds) * 1_000_000_000)
                server.cancel()
                throw OidcError.timeout(timeoutSeconds)
            }
            let result = try await group.next()!
            group.cancelAll()
            return result
        }

        // 5. 解析并校验 state
        let params = parseQuery(query)
        guard let receivedState = params["state"], receivedState == startResult.state else {
            throw OidcError.stateMismatch
        }
        if let errParam = params["error"] {
            throw OidcError.authError(errParam)
        }
        guard let token = params["token"], !token.isEmpty else {
            throw OidcError.badResponse("回调中没有 token 参数")
        }

        // 6. 直接从 JWT payload 解析用户信息（无需二次网络请求）
        let userInfo = parseJwtUserInfo(token: token)

        // 7. 构造 TokenPair（服务端直接给了 access_token，无需二次换取）
        return TokenPair(
            accessToken: token,
            refreshToken: params["refresh_token"] ?? "",
            expiresIn: Int64(params["expires_in"] ?? "0") ?? 0,
            userInfo: userInfo
        )
    }

    /// 从 server 的 /api/auth/me 获取当前用户信息
    static func fetchMeFromServer(cloudUrl: String, token: String) async throws -> OidcUserInfo {
        let base = cloudUrl.trimmingCharacters(in: .init(charactersIn: "/"))
        guard let url = URL(string: base + "/api/auth/me") else {
            throw OidcError.invalidUrl(base + "/api/auth/me")
        }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, resp) = try await URLSession.shared.data(for: req)
        if let http = resp as? HTTPURLResponse, http.statusCode < 200 || http.statusCode >= 300 {
            throw OidcError.httpError(http.statusCode)
        }
        return try JSONDecoder().decode(OidcUserInfo.self, from: data)
    }

    /// 从 JWT payload（base64 中间段）解析用户信息，作为离线回退方案
    static func parseJwtUserInfo(token: String) -> OidcUserInfo? {
        let parts = token.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count >= 2 else { return nil }
        var payload = String(parts[1])
        // base64url → base64
        payload = payload.replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        // 补足 padding
        let remainder = payload.count % 4
        if remainder != 0 { payload += String(repeating: "=", count: 4 - remainder) }
        guard let data = Data(base64Encoded: payload),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            NSLog("[OidcService] JWT payload decode failed")
            return nil
        }
        NSLog("[OidcService] JWT claims: %@", json.description)
        let sub = json["sub"] as? String ?? ""
        let name = json["name"] as? String
        let email = json["email"] as? String
        let preferredUsername = json["preferred_username"] as? String
        return OidcUserInfo(
            sub: sub, email: email, name: name, preferredUsername: preferredUsername)
    }

    /// 从 OIDC Issuer 的 userinfo 端点拉取用户信息（通过 Discovery 获取端点地址）
    static func fetchUserInfo(token: String, oidcIssuer: String) async throws -> OidcUserInfo {
        let issuerBase = oidcIssuer.trimmingCharacters(in: .init(charactersIn: "/"))

        // 1. 通过 OIDC Discovery 获取 userinfo_endpoint
        let userInfoEndpoint: String
        if let discoveryUrl = URL(string: issuerBase + "/.well-known/openid-configuration") {
            let (discoveryData, _) =
                (try? await URLSession.shared.data(from: discoveryUrl)) ?? (nil, nil)
            if let data = discoveryData,
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let endpoint = json["userinfo_endpoint"] as? String, !endpoint.isEmpty
            {
                userInfoEndpoint = endpoint
            } else {
                // Discovery 失败，回退到标准路径
                userInfoEndpoint = issuerBase + "/userinfo"
            }
        } else {
            userInfoEndpoint = issuerBase + "/userinfo"
        }

        // 2. 调用 userinfo 端点
        guard let url = URL(string: userInfoEndpoint) else {
            throw OidcError.invalidUrl(userInfoEndpoint)
        }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, resp) = try await URLSession.shared.data(for: req)
        if let http = resp as? HTTPURLResponse, http.statusCode < 200 || http.statusCode >= 300 {
            throw OidcError.httpError(http.statusCode)
        }
        return try JSONDecoder().decode(OidcUserInfo.self, from: data)
    }
}

// MARK: - 本地回调 HTTP server（POSIX socket）

private final class LocalCallbackServer {
    let port: UInt16
    private var serverFd: Int32 = -1

    init() throws {
        var fd = socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else { throw OidcError.serverBind("socket() failed") }

        var reuse: Int32 = 1
        setsockopt(
            fd, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout.size(ofValue: reuse)))

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_addr.s_addr = CFSwapInt32HostToBig(INADDR_LOOPBACK)
        addr.sin_port = 0

        let bindResult = withUnsafeMutablePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bindResult == 0 else {
            close(fd)
            throw OidcError.serverBind("bind() failed")
        }
        guard listen(fd, 1) == 0 else {
            close(fd)
            throw OidcError.serverBind("listen() failed")
        }

        var actual = sockaddr_in()
        var addrLen = socklen_t(MemoryLayout<sockaddr_in>.size)
        withUnsafeMutablePointer(to: &actual) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                getsockname(fd, $0, &addrLen)
            }
        }
        self.serverFd = fd
        self.port = UInt16(bigEndian: actual.sin_port)
    }

    deinit { if serverFd >= 0 { close(serverFd) } }

    func cancel() {
        if serverFd >= 0 {
            close(serverFd)
            serverFd = -1
        }
    }

    /// 阻塞等待一次 GET /callback?... 请求，返回 query string
    func waitForCallback() async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let fd = serverFd
            DispatchQueue.global(qos: .userInitiated).async {
                let clientFd = accept(fd, nil, nil)
                guard clientFd >= 0 else {
                    continuation.resume(throwing: OidcError.serverBind("accept() failed"))
                    return
                }
                defer { close(clientFd) }

                var buf = [UInt8](repeating: 0, count: 4096)
                let n = recv(clientFd, &buf, buf.count - 1, 0)
                let request = n > 0 ? String(bytes: buf.prefix(n), encoding: .utf8) ?? "" : ""

                // 返回简洁的成功页面
                let html = """
                    HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nConnection: close\r\n\r\n\
                    <!DOCTYPE html><html><body>\
                    <h2>登录成功 — 您可以关闭此选项卡。</h2>\
                    </body></html>
                    """
                _ = html.withCString { send(clientFd, $0, strlen($0), 0) }

                // 从 "GET /callback?foo=bar HTTP/1.1" 提取 query string
                var query = ""
                if let qStart = request.firstIndex(of: "?"),
                    let spaceAfter = request[qStart...].firstIndex(of: " ")
                {
                    query = String(request[qStart..<spaceAfter]).dropFirst().description
                }
                continuation.resume(returning: query)
            }
        }
    }
}

// MARK: - API 数据结构

private struct StartRequest: Encodable {
    let oidc_issuer: String
    let app_redirect_uri: String
}

private struct StartResponse: Decodable {
    let browser_url: String
    let state: String
}

struct TokenPair: Decodable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int64
    let userInfo: OidcUserInfo?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case userInfo = "user_info"
    }
}

struct OidcUserInfo: Codable {
    let sub: String
    let email: String?
    let name: String?
    let preferredUsername: String?

    enum CodingKeys: String, CodingKey {
        case sub
        case email
        case name
        case preferredUsername = "preferred_username"
    }

    /// 优先展示 name，其次 preferred_username，最后 sub
    var displayName: String {
        if let n = name, !n.isEmpty { return n }
        if let u = preferredUsername, !u.isEmpty { return u }
        return sub
    }
}

// MARK: - Keychain 存储

struct KeychainToken {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Int64?
    let userInfo: OidcUserInfo?

    private static let service = "ai.AgentSphere.app"
    private static let account = "oidc_token"

    static func save(_ token: KeychainToken) {
        var dict: [String: Any] = [
            "access_token": token.accessToken,
            "refresh_token": token.refreshToken,
        ]
        if let ea = token.expiresAt { dict["expires_at"] = ea }
        if let ui = token.userInfo,
            let data = try? JSONEncoder().encode(ui)
        {
            dict["user_info"] = String(data: data, encoding: .utf8)
        }
        guard let data = try? JSONSerialization.data(withJSONObject: dict) else { return }

        let del: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(del as CFDictionary)

        let add: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
        SecItemAdd(add as CFDictionary, nil)
    }

    static func load() -> KeychainToken? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
            let data = result as? Data,
            let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let at = dict["access_token"] as? String, !at.isEmpty,
            let rt = dict["refresh_token"] as? String
        else { return nil }

        var userInfo: OidcUserInfo?
        if let uiStr = dict["user_info"] as? String,
            let uiData = uiStr.data(using: .utf8)
        {
            userInfo = try? JSONDecoder().decode(OidcUserInfo.self, from: uiData)
        }
        return KeychainToken(
            accessToken: at,
            refreshToken: rt,
            expiresAt: dict["expires_at"] as? Int64,
            userInfo: userInfo
        )
    }

    static func clear() {
        let del: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(del as CFDictionary)
    }
}

// MARK: - 错误类型

enum OidcError: LocalizedError {
    case invalidUrl(String)
    case httpError(Int)
    case badResponse(String)
    case serverBind(String)
    case timeout(Int)
    case stateMismatch
    case authError(String)

    var errorDescription: String? {
        switch self {
        case .invalidUrl(let u): return "无效 URL: \(u)"
        case .httpError(let c): return "HTTP 错误 \(c)"
        case .badResponse(let m): return "响应异常: \(m)"
        case .serverBind(let m): return "本地服务启动失败: \(m)"
        case .timeout(let s): return "登录超时（\(s) 秒），请重试"
        case .stateMismatch: return "安全校验失败（state 不匹配）"
        case .authError(let e): return "认证失败: \(e)"
        }
    }
}

// MARK: - 工具函数

private func parseQuery(_ query: String) -> [String: String] {
    var result = [String: String]()
    let q = query.hasPrefix("?") ? String(query.dropFirst()) : query
    for pair in q.split(separator: "&") {
        let parts = pair.split(separator: "=", maxSplits: 1)
        if parts.count == 2 {
            let key = String(parts[0]).removingPercentEncoding ?? String(parts[0])
            let val = String(parts[1]).removingPercentEncoding ?? String(parts[1])
            result[key] = val
        }
    }
    return result
}