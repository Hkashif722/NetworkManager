import Foundation

/// Protocol defining the structure of an API endpoint
public protocol EndpointModel {
    var path: String { get }
    var method: HTTPMethod { get }
    var headers: [String: String]? { get }
    var expectedContentTypes: [String] { get }
    var baseURL: String { get }
}

public extension EndpointModel {
    var baseURL: String {
        APIConfiguration.shared.baseURL
    }
}

// Default implementation so existing models don't break
public extension EndpointModel {
    var expectedContentTypes: [String] { ["application/json", "text/plain"] }
}

/// Default implementation of EndpointModel
public struct APIEndpoint: EndpointModel {
    public let path: String
    public let method: HTTPMethod
    public let headers: [String: String]?
    public let baseURL: String
    
    public init(
        path: String,
        method: HTTPMethod = .get,
        baseURL: String,
        headers: [String: String]? = nil
    ) {
        self.path = path
        self.method = method
        self.baseURL = baseURL
        self.headers = headers
    }
}
