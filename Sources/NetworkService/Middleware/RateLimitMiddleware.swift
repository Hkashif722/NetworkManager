import Foundation

/// Middleware for handling rate limit responses
public struct RateLimitMiddleware: NetworkMiddleware {
    
    public init() {}
    
    public func prepare(request: URLRequest) throws -> URLRequest {
        return request
    }
    
    public func process(data: Data, response: HTTPURLResponse) throws -> Data {
        // Check for rate limit headers
        if response.statusCode == 429 {
            if let retryAfter = response.value(forHTTPHeaderField: "Retry-After") {
                throw APIError.rateLimitExceeded(retryAfter: retryAfter)
            }
            throw APIError.rateLimitExceeded(retryAfter: nil)
        }
        return data
    }
}
