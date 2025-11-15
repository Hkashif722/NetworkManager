import Foundation

/// Protocol for implementing response validators
public protocol ResponseValidator {
    /// Validates the response data
    /// - Parameters:
    ///   - data: Response data to validate
    ///   - response: HTTPURLResponse
    /// - Returns: Validated data
    /// - Throws: APIError if validation fails
    func validate(data: Data, response: HTTPURLResponse) throws -> Data
}
