import Foundation

/// Middleware for adding authentication tokens to requests
public struct AuthenticationMiddleware: NetworkMiddleware {
    
    private let tokenProvider: () -> String?
    
    public init(tokenProvider: @escaping () -> String?) {
        self.tokenProvider = tokenProvider
    }
    
    public func prepare(request: URLRequest) throws -> URLRequest {
        var modifiedRequest = request
        if let token = tokenProvider() {
            modifiedRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return modifiedRequest
    }
    
    public func process(data: Data, response: HTTPURLResponse) throws -> Data {
        return data
    }
}
