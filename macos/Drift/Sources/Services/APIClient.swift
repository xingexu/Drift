import Foundation
import Network
import os.log
import Security

// MARK: - Keychain Helper

enum KeychainHelper {

    private static let service = "net.drift.app"

    static func save(key: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)

        var addQuery = query
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    static func read(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - API Error Types

enum APIError: LocalizedError, Equatable {
    case networkUnavailable
    case timeout
    case unauthorized
    case forbidden
    case notFound(resource: String)
    case rateLimited(retryAfter: TimeInterval?)
    case serverError(statusCode: Int, message: String)
    case decodingFailed(context: String)
    case invalidURL(path: String)
    case requestFailed(message: String)

    var errorDescription: String? {
        switch self {
        case .networkUnavailable:
            return "You appear to be offline. Drift will sync when your connection returns."
        case .timeout:
            return "The request timed out. Please check your connection and try again."
        case .unauthorized:
            return "Your session has expired. Please sign in again."
        case .forbidden:
            return "You don't have permission to perform this action."
        case .notFound(let resource):
            return "The requested \(resource) could not be found."
        case .rateLimited:
            return "Too many requests. Please wait a moment and try again."
        case .serverError(_, let message):
            return message.isEmpty ? "Something went wrong on our end. Please try again later." : message
        case .decodingFailed:
            return "We received an unexpected response. Please try again or update Drift."
        case .invalidURL(let path):
            return "Invalid request path: \(path)"
        case .requestFailed(let message):
            return message
        }
    }

    var isRetryable: Bool {
        switch self {
        case .networkUnavailable, .timeout, .rateLimited:
            return true
        case .serverError(let code, _):
            return code >= 500
        default:
            return false
        }
    }

    static func == (lhs: APIError, rhs: APIError) -> Bool {
        switch (lhs, rhs) {
        case (.networkUnavailable, .networkUnavailable),
             (.timeout, .timeout),
             (.unauthorized, .unauthorized),
             (.forbidden, .forbidden):
            return true
        case (.notFound(let a), .notFound(let b)):
            return a == b
        case (.rateLimited(let a), .rateLimited(let b)):
            return a == b
        case (.serverError(let cA, let mA), .serverError(let cB, let mB)):
            return cA == cB && mA == mB
        case (.decodingFailed(let a), .decodingFailed(let b)):
            return a == b
        case (.invalidURL(let a), .invalidURL(let b)):
            return a == b
        case (.requestFailed(let a), .requestFailed(let b)):
            return a == b
        default:
            return false
        }
    }
}

struct ErrorResponse: Decodable {
    let error: String?
    let message: String?
}

// MARK: - Network Monitor

@MainActor
final class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    @Published private(set) var isConnected: Bool = true

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "net.drift.network-monitor")

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                guard let self else { return }
                let nowConnected = path.status == .satisfied
                let wasConnected = self.isConnected
                self.isConnected = nowConnected
                // Notify observers (e.g. AppDelegate) so the offline queue can
                // drain the moment connectivity is restored — previously this
                // notification was observed but never posted, so the queue only
                // drained on app foreground.
                if nowConnected != wasConnected {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("NetworkStatusChanged"),
                        object: nil
                    )
                }
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}

// MARK: - Cache Entry

private struct CacheEntry {
    let data: Data
    let response: HTTPURLResponse
    let timestamp: Date
    let maxAge: TimeInterval

    var isExpired: Bool {
        Date().timeIntervalSince(timestamp) > maxAge
    }
}

// MARK: - Offline Request Queue

private struct QueuedRequest: Codable {
    let id: UUID
    let method: String
    let path: String
    let bodyData: Data?
    let requiresAuth: Bool
    let createdAt: Date
}

// MARK: - API Client

actor APIClient {
    static let shared = APIClient()

    private let baseURL: String
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let logger = Logger(subsystem: "net.drift.app", category: "APIClient")

    // Retry configuration
    private let maxRetries = 3
    private let baseRetryDelay: TimeInterval = 1.0
    private let requestTimeout: TimeInterval = 30.0

    // Token management
    private var tokenExpiresAt: Date?
    private var isRefreshing = false
    private var refreshContinuations: [CheckedContinuation<Bool, Never>] = []

    // GET response cache
    private var cache: [String: CacheEntry] = [:]
    private let defaultCacheDuration: TimeInterval = 60 // 1 minute

    // Offline request queue
    private var offlineQueue: [QueuedRequest] = []
    private var isDrainingQueue = false

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.waitsForConnectivity = false

        self.session = URLSession(configuration: config)
        self.baseURL = Self.resolveBaseURL()

        self.decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601

        self.encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601

        // Load offline queue synchronously during init (nonisolated context).
        // Both decoder and offlineQueueFileURL use only the properties we just set.
        if let url = Self.staticOfflineQueueFileURL(),
           let data = try? Data(contentsOf: url) {
            let dec = JSONDecoder()
            dec.keyDecodingStrategy = .convertFromSnakeCase
            dec.dateDecodingStrategy = .iso8601
            self.offlineQueue = (try? dec.decode([QueuedRequest].self, from: data)) ?? []
        }
    }

    private static func resolveBaseURL() -> String {
        if let override = ProcessInfo.processInfo.environment["DRIFT_API_URL"] {
            return override
        }
        #if DEBUG
        return "http://localhost:3001/api"
        #else
        return "https://api.usedrift.com/api"
        #endif
    }

    // MARK: - Auth

    struct LoginResponse: Decodable {
        let accessToken: String
        let refreshToken: String
        let expiresIn: Int
        let user: UserResponse
    }

    struct UserResponse: Decodable {
        let userId: String
        let email: String
        let name: String?
        let plan: String
    }

    struct SignupResponse: Decodable {
        let message: String
        let userId: String?
    }

    func login(email: String, password: String) async throws -> LoginResponse {
        let response: LoginResponse = try await post(
            "/auth/login",
            body: ["email": email, "password": password]
        )
        storeTokenExpiry(expiresIn: response.expiresIn)
        return response
    }

    func signup(email: String, password: String, name: String?) async throws -> SignupResponse {
        var body: [String: String] = ["email": email, "password": password]
        if let name = name { body["name"] = name }
        return try await post("/auth/signup", body: body)
    }

    func refreshToken(_ refreshToken: String) async throws -> LoginResponse {
        let response: LoginResponse = try await post(
            "/auth/refresh",
            body: ["refreshToken": refreshToken],
            skipAuthRefresh: true
        )
        storeTokenExpiry(expiresIn: response.expiresIn)
        return response
    }

    // MARK: - OAuth

    struct OAuthURLResponse: Decodable {
        let url: String
    }

    func appleSignIn(identityToken: String, name: String?, email: String?) async throws -> LoginResponse {
        var body: [String: String] = ["identityToken": identityToken]
        if let name = name { body["name"] = name }
        if let email = email { body["email"] = email }
        let response: LoginResponse = try await post("/auth/apple", body: body)
        storeTokenExpiry(expiresIn: response.expiresIn)
        return response
    }

    func getGoogleOAuthURL() async throws -> OAuthURLResponse {
        return try await get("/auth/google/url", auth: false)
    }

    func googleSignIn(code: String) async throws -> LoginResponse {
        let response: LoginResponse = try await post("/auth/google", body: ["code": code])
        storeTokenExpiry(expiresIn: response.expiresIn)
        return response
    }

    // MARK: - User Profile

    struct ProfileResponse: Decodable {
        let userId: String
        let email: String
        let plan: String
        let subscriptionStatus: String
        let trialEndsAt: String?
        let cancelAt: String?
    }

    func getProfile() async throws -> ProfileResponse {
        return try await get("/me", cacheDuration: 120)
    }

    // MARK: - Billing

    struct CheckoutResponse: Decodable {
        let url: String
    }

    func startCheckout(plan: String, interval: String) async throws -> CheckoutResponse {
        return try await post(
            "/billing/checkout",
            body: ["plan": plan, "interval": interval],
            auth: true
        )
    }

    func openBillingPortal() async throws -> CheckoutResponse {
        return try await post(
            "/billing/portal",
            body: [:] as [String: String],
            auth: true
        )
    }

    // MARK: - Sessions

    struct SessionStartResponse: Decodable {
        let sessionId: Int
    }

    func startSession() async throws -> SessionStartResponse {
        return try await post(
            "/sessions/start",
            body: ["platform": "desktop"],
            auth: true
        )
    }

    func endSession(id: Int, data: [String: Any]) async throws {
        let _: EmptyResponse = try await post(
            "/sessions/\(id)/end",
            body: data,
            auth: true,
            enqueueIfOffline: true
        )
    }

    // MARK: - Cache Management

    func invalidateCache(path: String? = nil) {
        if let path = path {
            cache.removeValue(forKey: path)
        } else {
            cache.removeAll()
        }
    }

    // MARK: - Offline Queue

    func drainOfflineQueue() async {
        guard !isDrainingQueue else { return }
        isDrainingQueue = true
        defer { isDrainingQueue = false }

        var remaining: [QueuedRequest] = []

        for request in offlineQueue {
            // Drop requests older than 24 hours
            if Date().timeIntervalSince(request.createdAt) > 86400 {
                logger.info("[Queue] Dropping stale request: \(request.path, privacy: .public)")
                continue
            }

            do {
                var urlRequest = try buildURLRequest(
                    method: request.method,
                    path: request.path,
                    auth: request.requiresAuth
                )
                urlRequest.httpBody = request.bodyData
                let (_, response) = try await session.data(for: urlRequest)
                if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                    logger.info("[Queue] Drained: \(request.method, privacy: .public) \(request.path, privacy: .public)")
                } else {
                    remaining.append(request)
                }
            } catch {
                remaining.append(request)
            }
        }

        offlineQueue = remaining
        persistOfflineQueue()
    }

    // MARK: - HTTP Core

    private func get<T: Decodable>(
        _ path: String,
        auth: Bool = true,
        cacheDuration: TimeInterval? = nil
    ) async throws -> T {
        // Check cache
        let ttl = cacheDuration ?? defaultCacheDuration
        if let entry = cache[path], !entry.isExpired {
            logDebug("Cache HIT", method: "GET", path: path)
            return try decoder.decode(T.self, from: entry.data)
        }

        let request = try await buildAuthenticatedRequest(method: "GET", path: path, auth: auth)
        let (data, response) = try await executeWithRetry(request: request, path: path)

        let result: T = try decodeResponse(data: data, response: response, path: path)

        // Store in cache
        if let httpResponse = response as? HTTPURLResponse {
            cache[path] = CacheEntry(
                data: data,
                response: httpResponse,
                timestamp: Date(),
                maxAge: ttl
            )
        }

        return result
    }

    private func post<T: Decodable>(
        _ path: String,
        body: Any,
        auth: Bool = false,
        skipAuthRefresh: Bool = false,
        enqueueIfOffline: Bool = false
    ) async throws -> T {
        // Check connectivity for queuable requests
        let isOnline = await NetworkMonitor.shared.isConnected
        if !isOnline && enqueueIfOffline {
            let bodyData: Data?
            if let encodable = body as? Encodable {
                bodyData = try? encoder.encode(AnyEncodable(encodable))
            } else {
                bodyData = try? JSONSerialization.data(withJSONObject: body)
            }
            let queued = QueuedRequest(
                id: UUID(),
                method: "POST",
                path: path,
                bodyData: bodyData,
                requiresAuth: auth,
                createdAt: Date()
            )
            offlineQueue.append(queued)
            persistOfflineQueue()
            logDebug("Queued offline", method: "POST", path: path)
            // Return a placeholder for fire-and-forget endpoints
            if T.self == EmptyResponse.self {
                return EmptyResponse() as! T
            }
            throw APIError.networkUnavailable
        }

        var request = try await buildAuthenticatedRequest(
            method: "POST",
            path: path,
            auth: auth,
            skipRefresh: skipAuthRefresh
        )

        if let encodable = body as? Encodable {
            request.httpBody = try encoder.encode(AnyEncodable(encodable))
        } else {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await executeWithRetry(request: request, path: path)
        return try decodeResponse(data: data, response: response, path: path)
    }

    // MARK: - Request Building

    private func buildURLRequest(method: String, path: String, auth: Bool) throws -> URLRequest {
        guard let url = URL(string: baseURL + path) else {
            throw APIError.invalidURL(path: path)
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Drift-macOS/1.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = requestTimeout
        return request
    }

    private func buildAuthenticatedRequest(
        method: String,
        path: String,
        auth: Bool,
        skipRefresh: Bool = false
    ) async throws -> URLRequest {
        var request = try buildURLRequest(method: method, path: path, auth: auth)

        if auth {
            if !skipRefresh {
                await ensureValidToken()
            }
            if let token = await getToken() {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
        }

        return request
    }

    // MARK: - Retry with Exponential Backoff

    private func executeWithRetry(
        request: URLRequest,
        path: String
    ) async throws -> (Data, URLResponse) {
        var lastError: Error = APIError.requestFailed(message: "Unknown error")
        let method = request.httpMethod ?? "GET"

        for attempt in 0...maxRetries {
            if attempt > 0 {
                let jitter = Double.random(in: 0...0.5)
                let delay = baseRetryDelay * pow(2.0, Double(attempt - 1)) + jitter
                logDebug("Retry \(attempt)/\(maxRetries) after \(String(format: "%.1f", delay))s", method: method, path: path)
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }

            do {
                logDebug("Request", method: method, path: path)
                let (data, response) = try await session.data(for: request)

                guard let http = response as? HTTPURLResponse else {
                    throw APIError.requestFailed(message: "Invalid response type")
                }

                logDebug("Response \(http.statusCode)", method: method, path: path)

                // Handle 401 with token refresh (only once)
                if http.statusCode == 401 && attempt == 0 {
                    if await refreshAccessToken() {
                        // Rebuild request with new token
                        var refreshedRequest = request
                        if let token = await getToken() {
                            refreshedRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                        }
                        return try await session.data(for: refreshedRequest)
                    }
                    throw APIError.unauthorized
                }

                // Non-retryable client errors
                if (400...499).contains(http.statusCode) {
                    throw mapHTTPError(statusCode: http.statusCode, data: data)
                }

                // Retryable server errors
                if http.statusCode >= 500 {
                    let mapped = mapHTTPError(statusCode: http.statusCode, data: data)
                    lastError = mapped
                    continue
                }

                return (data, response)
            } catch let urlError as URLError {
                lastError = mapURLError(urlError)
                let mapped = lastError as? APIError
                if mapped?.isRetryable != true {
                    throw lastError
                }
                continue
            } catch let apiError as APIError {
                if !apiError.isRetryable { throw apiError }
                lastError = apiError
                continue
            } catch {
                throw error
            }
        }

        throw lastError
    }

    // MARK: - Response Decoding & Validation

    private func decodeResponse<T: Decodable>(
        data: Data,
        response: URLResponse,
        path: String
    ) throws -> T {
        guard let http = response as? HTTPURLResponse else {
            throw APIError.requestFailed(message: "Invalid response type")
        }

        guard (200...299).contains(http.statusCode) else {
            throw mapHTTPError(statusCode: http.statusCode, data: data)
        }

        // Validate content type
        if let contentType = http.value(forHTTPHeaderField: "Content-Type"),
           !contentType.contains("application/json") && !data.isEmpty {
            logDebug("Unexpected Content-Type: \(contentType)", method: "?", path: path)
        }

        // Handle empty response bodies
        if data.isEmpty || (data.count == 2 && String(data: data, encoding: .utf8) == "{}") {
            if T.self == EmptyResponse.self {
                return EmptyResponse() as! T
            }
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch let decodingError {
            logger.error("Decode error on \(path, privacy: .public): \(decodingError.localizedDescription, privacy: .public)")
            throw APIError.decodingFailed(context: "Failed to decode response from \(path)")
        }
    }

    // MARK: - Error Mapping

    private func mapHTTPError(statusCode: Int, data: Data) -> APIError {
        let serverMessage = (try? decoder.decode(ErrorResponse.self, from: data))
            .flatMap { $0.error ?? $0.message }

        switch statusCode {
        case 401:
            return .unauthorized
        case 403:
            return .forbidden
        case 404:
            return .notFound(resource: "resource")
        case 429:
            return .rateLimited(retryAfter: nil)
        case 500...599:
            return .serverError(
                statusCode: statusCode,
                message: serverMessage ?? "Internal server error"
            )
        default:
            return .requestFailed(
                message: serverMessage ?? "Request failed with status \(statusCode)"
            )
        }
    }

    private func mapURLError(_ error: URLError) -> APIError {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed:
            return .networkUnavailable
        case .timedOut:
            return .timeout
        case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
            return .networkUnavailable
        case .secureConnectionFailed, .serverCertificateUntrusted:
            return .requestFailed(message: "Secure connection failed. Please update Drift.")
        default:
            return .requestFailed(message: error.localizedDescription)
        }
    }

    // MARK: - Token Management

    private func storeTokenExpiry(expiresIn: Int) {
        // Refresh 5 minutes before actual expiry for a safety margin
        let margin: TimeInterval = 300
        tokenExpiresAt = Date().addingTimeInterval(TimeInterval(expiresIn) - margin)
    }

    private func ensureValidToken() async {
        guard let expiresAt = tokenExpiresAt else { return }
        if Date() >= expiresAt {
            _ = await refreshAccessToken()
        }
    }

    private func refreshAccessToken() async -> Bool {
        // Coalesce concurrent refresh attempts
        if isRefreshing {
            return await withCheckedContinuation { continuation in
                refreshContinuations.append(continuation)
            }
        }

        isRefreshing = true
        defer {
            isRefreshing = false
            let result = tokenExpiresAt != nil
            for continuation in refreshContinuations {
                continuation.resume(returning: result)
            }
            refreshContinuations.removeAll()
        }

        guard let rt = KeychainHelper.read(key: "drift_refresh_token") else {
            logDebug("No refresh token available", method: "-", path: "/auth/refresh")
            return false
        }

        do {
            let response: LoginResponse = try await post(
                "/auth/refresh",
                body: ["refreshToken": rt],
                skipAuthRefresh: true
            )
            storeTokenExpiry(expiresIn: response.expiresIn)

            await MainActor.run {
                AppState.shared.handleTokenRefresh(
                    accessToken: response.accessToken,
                    refreshToken: response.refreshToken
                )
            }
            logDebug("Token refreshed", method: "-", path: "/auth/refresh")
            return true
        } catch {
            logger.error("Token refresh failed: \(error.localizedDescription, privacy: .public)")
            await MainActor.run {
                AppState.shared.logout()
            }
            return false
        }
    }

    @MainActor
    private func getToken() -> String? {
        return AppState.shared.accessToken
    }

    // MARK: - Debug Logging

    private func logDebug(_ message: String, method: String, path: String) {
        #if DEBUG
        logger.debug("[\(method, privacy: .public)] \(path, privacy: .public) - \(message, privacy: .public)")
        #endif
    }

    // MARK: - Offline Queue Persistence

    private func persistOfflineQueue() {
        guard let url = offlineQueueFileURL() else { return }
        let dir = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? encoder.encode(offlineQueue).write(to: url)
    }

    private static func staticOfflineQueueFileURL() -> URL? {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("net.drift.app", isDirectory: true)
            .appendingPathComponent("offline_queue.json")
    }

    private func offlineQueueFileURL() -> URL? {
        Self.staticOfflineQueueFileURL()
    }
}

// MARK: - Empty Response (for fire-and-forget endpoints)

struct EmptyResponse: Decodable {
    init() {}
    init(from decoder: Decoder) throws {}
}

// MARK: - AnyEncodable wrapper

struct AnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void

    init(_ wrapped: Encodable) {
        _encode = wrapped.encode
    }

    func encode(to encoder: Encoder) throws {
        try _encode(encoder)
    }
}
