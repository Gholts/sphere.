import Foundation

protocol ProxyBackendClient: Sendable {
    var profile: APIProfile { get }

    func testConnection() async throws -> BackendOverview
    func version() async throws -> String
    func overview() async throws -> BackendOverview
    func configs() async throws -> [String: JSONValue]
    func patchConfigs(_ values: [String: JSONValue]) async throws
    func reloadConfig() async throws
    func clashMode() async throws -> ClashMode
    func updateClashMode(_ mode: ClashMode) async throws
    func proxies() async throws -> ProxyCollection
    func selectProxy(group: String, proxy: String) async throws
    func delayProxy(_ proxy: String, url: String, timeout: Int) async throws -> Int?
    func delayProxyGroup(_ group: String, url: String, timeout: Int) async throws -> [String: Int]
    func proxyProviders() async throws -> [ProxyProvider]
    func refreshProxyProvider(_ name: String) async throws
    func rules() async throws -> [RuleItem]
    func ruleProviders() async throws -> [RuleProvider]
    func refreshRuleProvider(_ name: String) async throws
    func connections() async throws -> ConnectionsSnapshot
    func closeConnection(_ id: String) async throws
    func closeAllConnections() async throws
    func upgradeCore(channel: CoreUpdateChannel) async throws
    func logs(level: LogLevel) -> AsyncThrowingStream<LogEntry, Error>
    func connectionEvents(interval: Int) -> AsyncThrowingStream<ConnectionsSnapshot, Error>
    func memoryEvents() -> AsyncThrowingStream<MemorySnapshot, Error>
    func trafficEvents() -> AsyncThrowingStream<TrafficSnapshot, Error>
}

enum BackendClientFactory {
    static func make(profile: APIProfile) -> any ProxyBackendClient {
        switch profile.kind {
        case .mihomo:
            return MihomoClient(profile: profile)
        case .singbox:
            return SingboxClient(profile: profile)
        case .surge:
            return UnsupportedBackendClient(profile: profile)
        }
    }
}

struct UnsupportedBackendClient: ProxyBackendClient {
    var profile: APIProfile

    func testConnection() async throws -> BackendOverview { throw BackendError.unsupportedBackend(profile.kind.title) }
    func version() async throws -> String { throw BackendError.unsupportedBackend(profile.kind.title) }
    func overview() async throws -> BackendOverview { throw BackendError.unsupportedBackend(profile.kind.title) }
    func configs() async throws -> [String: JSONValue] { throw BackendError.unsupportedBackend(profile.kind.title) }
    func patchConfigs(_ values: [String: JSONValue]) async throws { throw BackendError.unsupportedBackend(profile.kind.title) }
    func reloadConfig() async throws { throw BackendError.unsupportedBackend(profile.kind.title) }
    func clashMode() async throws -> ClashMode { throw BackendError.unsupportedBackend(profile.kind.title) }
    func updateClashMode(_ mode: ClashMode) async throws { throw BackendError.unsupportedBackend(profile.kind.title) }
    func proxies() async throws -> ProxyCollection { throw BackendError.unsupportedBackend(profile.kind.title) }
    func selectProxy(group: String, proxy: String) async throws { throw BackendError.unsupportedBackend(profile.kind.title) }
    func delayProxy(_ proxy: String, url: String, timeout: Int) async throws -> Int? { throw BackendError.unsupportedBackend(profile.kind.title) }
    func delayProxyGroup(_ group: String, url: String, timeout: Int) async throws -> [String: Int] { throw BackendError.unsupportedBackend(profile.kind.title) }
    func proxyProviders() async throws -> [ProxyProvider] { throw BackendError.unsupportedBackend(profile.kind.title) }
    func refreshProxyProvider(_ name: String) async throws { throw BackendError.unsupportedBackend(profile.kind.title) }
    func rules() async throws -> [RuleItem] { throw BackendError.unsupportedBackend(profile.kind.title) }
    func ruleProviders() async throws -> [RuleProvider] { throw BackendError.unsupportedBackend(profile.kind.title) }
    func refreshRuleProvider(_ name: String) async throws { throw BackendError.unsupportedBackend(profile.kind.title) }
    func connections() async throws -> ConnectionsSnapshot { throw BackendError.unsupportedBackend(profile.kind.title) }
    func closeConnection(_ id: String) async throws { throw BackendError.unsupportedBackend(profile.kind.title) }
    func closeAllConnections() async throws { throw BackendError.unsupportedBackend(profile.kind.title) }
    func upgradeCore(channel: CoreUpdateChannel) async throws { throw BackendError.unsupportedBackend(profile.kind.title) }
    func logs(level: LogLevel) -> AsyncThrowingStream<LogEntry, Error> {
        AsyncThrowingStream { continuation in continuation.finish(throwing: BackendError.unsupportedBackend(profile.kind.title)) }
    }
    func connectionEvents(interval: Int) -> AsyncThrowingStream<ConnectionsSnapshot, Error> {
        AsyncThrowingStream { continuation in continuation.finish(throwing: BackendError.unsupportedBackend(profile.kind.title)) }
    }
    func memoryEvents() -> AsyncThrowingStream<MemorySnapshot, Error> {
        AsyncThrowingStream { continuation in continuation.finish(throwing: BackendError.unsupportedBackend(profile.kind.title)) }
    }
    func trafficEvents() -> AsyncThrowingStream<TrafficSnapshot, Error> {
        AsyncThrowingStream { continuation in continuation.finish(throwing: BackendError.unsupportedBackend(profile.kind.title)) }
    }
}

enum ProxyLatencyTestDefaults {
    nonisolated static let url = "https://www.gstatic.com/generate_204"
    nonisolated static let timeout = 5000
    nonisolated static let maxConcurrentGroups = 3
}

enum BackendError: LocalizedError, Equatable, Sendable {
    case invalidBaseURL
    case invalidResponse
    case httpStatus(Int, String)
    case unsupportedBackend(String)

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL:
            return "Bad backend URL"
        case .invalidResponse:
            return "Bad backend response"
        case .httpStatus(let status, let body):
            return "HTTP \(status): \(HTTPErrorBodyDisplay.message(from: body))"
        case .unsupportedBackend(let backend):
            return "\(backend) backend not implemented"
        }
    }
}

private enum HTTPErrorBodyDisplay {
    private static let preferredKeys = ["message", "error", "detail", "reason", "description"]

    static func message(from body: String) -> String {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            let data = trimmed.data(using: .utf8),
            let object = try? JSONSerialization.jsonObject(with: data)
        else {
            return trimmed
        }

        return message(fromJSONObject: object) ?? trimmed
    }

    private static func message(fromJSONObject object: Any) -> String? {
        if let text = object as? String {
            return text
        }
        if let number = object as? NSNumber {
            return number.stringValue
        }
        if let dictionary = object as? [String: Any] {
            for key in preferredKeys {
                if let value = dictionary[key], let message = message(fromJSONObject: value) {
                    return message
                }
            }
            if dictionary.count == 1, let value = dictionary.values.first {
                return message(fromJSONObject: value)
            }
        }
        return nil
    }
}

struct URLRequestFactory {
    static func request(
        profile: APIProfile,
        path: String,
        query: [URLQueryItem] = [],
        method: String = "GET",
        body: Data? = nil,
        timeoutInterval: TimeInterval = 8
    ) throws -> URLRequest {
        guard var components = URLComponents(string: URLNormalizer.normalizedBaseURL(profile.baseURL)) else {
            throw BackendError.invalidBaseURL
        }
        components.percentEncodedPath = components.percentEncodedPath + path
        if !query.isEmpty {
            components.queryItems = query
        }
        guard let url = components.url else {
            throw BackendError.invalidBaseURL
        }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: timeoutInterval)
        request.httpMethod = method
        if !profile.secret.isEmpty {
            request.setValue("Bearer \(profile.secret)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        return request
    }
}
