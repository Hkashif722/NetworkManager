import Foundation

/// Validator for checking if response data is empty
public struct EmptyResponseValidator: ResponseValidator {
    
    public init() {}
    
    public func validate(data: Data, response: HTTPURLResponse) throws -> Data {
        if data.isEmpty && response.statusCode != 204 {
            throw APIError.noData
        }
        return data
    }
}
