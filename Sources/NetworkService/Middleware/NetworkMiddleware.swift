import Foundation

/// Protocol for implementing request/response middleware
public protocol NetworkMiddleware {
    /// Called before the request is sent
    /// - Parameter request: The URLRequest to be modified
    /// - Returns: Modified URLRequest
    /// - Throws: APIError if preparation fails
    func prepare(request: URLRequest) throws -> URLRequest
    
    /// Called after receiving the response
    /// - Parameters:
    ///   - data: Response data
    ///   - response: HTTPURLResponse
    /// - Returns: Processed data
    /// - Throws: APIError if processing fails
    func process(data: Data, response: HTTPURLResponse) throws -> Data
}
