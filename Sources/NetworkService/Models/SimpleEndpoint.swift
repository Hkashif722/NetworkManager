import Foundation

// MARK: - Global API Configuration
/// Configure once in your app initialization
public class APIConfiguration {
    public static let shared = APIConfiguration()
    
    /// Base URL for all API requests (can be overridden per endpoint)
    public var baseURL: String = ""
    
    /// API Key for app identification (automatically added to all requests)
    public var apiKey: String?
    
    /// Custom headers to add to every request
    public var defaultHeaders: [String: String] = [:]
    
    /// Header key for API Key (default: "X-API-Key")
    public var apiKeyHeaderName: String = "X-API-Key"
    
    private init() {}
    
    /// Configure API settings once in your app
    public func configure(
        baseURL: String,
        apiKey: String? = nil,
        apiKeyHeaderName: String = "X-API-Key",
        defaultHeaders: [String: String] = [:]
    ) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.apiKeyHeaderName = apiKeyHeaderName
        self.defaultHeaders = defaultHeaders
    }
}

// MARK: - Simple Endpoint Protocol
/// Simplified endpoint protocol with smart defaults
public protocol SimpleEndpoint {
    var path: String { get }
    var method: HTTPMethod { get }
    
    // Optional - uses global config if not provided
    var baseURL: String? { get }
    var customHeaders: [String: String]? { get }
}

// MARK: - Default Implementation
public extension SimpleEndpoint {
    /// Uses global baseURL if not specified
    var baseURL: String? { nil }
    
    /// No custom headers by default
    var customHeaders: [String: String]? { nil }
    
    /// Computed property that merges all headers
    var headers: [String: String] {
        var headers = APIConfiguration.shared.defaultHeaders
        
        // Add API Key if configured
        if let apiKey = APIConfiguration.shared.apiKey {
            headers[APIConfiguration.shared.apiKeyHeaderName] = apiKey
        }
        
        // Add custom headers (these can override defaults)
        if let customHeaders = customHeaders {
            headers.merge(customHeaders) { _, new in new }
        }
        
        return headers.isEmpty ? [:] : headers
    }
    
    /// Returns the effective base URL
    var effectiveBaseURL: String {
        return baseURL ?? APIConfiguration.shared.baseURL
    }
}

// MARK: - Convert SimpleEndpoint to EndpointModel
extension SimpleEndpoint {
    public func toEndpointModel() -> EndpointModel {
        return APIEndpoint(
            path: path,
            method: method,
            baseURL: effectiveBaseURL,
            headers: headers.isEmpty ? nil : headers
        )
    }
}

// MARK: - Convenience Request Methods
extension ApiService {
    
    // MARK: - GET
    public func get<T: Decodable>(
        _ endpoint: SimpleEndpoint,
        type: T.Type
    ) async throws -> T {
        return try await requestGetHeader(
            type: type,
            model: endpoint.toEndpointModel()
        )
    }
    
    // MARK: - POST
    public func post<T: Decodable, P: Encodable>(
        _ endpoint: SimpleEndpoint,
        payload: P,
        type: T.Type
    ) async throws -> T {
        return try await requestPostHeader(
            type: type,
            model: endpoint.toEndpointModel(),
            payload: payload
        )
    }
    
    // MARK: - PUT
    public func put<T: Decodable, P: Encodable>(
        _ endpoint: SimpleEndpoint,
        payload: P,
        type: T.Type
    ) async throws -> T {
        return try await requestPutHeader(
            type: type,
            model: endpoint.toEndpointModel(),
            payload: payload
        )
    }
    
    // MARK: - DELETE
    public func delete<T: Decodable>(
        _ endpoint: SimpleEndpoint,
        type: T.Type
    ) async throws -> T {
        return try await requestDeleteHeader(
            type: type,
            model: endpoint.toEndpointModel()
        )
    }
    
    // MARK: - PATCH
    public func patch<T: Decodable, P: Encodable>(
        _ endpoint: SimpleEndpoint,
        payload: P,
        type: T.Type
    ) async throws -> T {
        return try await requestPatchHeader(
            type: type,
            model: endpoint.toEndpointModel(),
            payload: payload
        )
    }
}
