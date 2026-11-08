import Foundation

/// Validator for checking if response data is empty
public struct EmptyResponseValidator: ResponseValidator {
    
    public init() {}
    
    public func validate(data: Data, response: HTTPURLResponse) throws -> Data {
        // Allow empty responses for successful status codes (200–299)
        if data.isEmpty {
            guard (200...299).contains(response.statusCode) else {
                throw APIError.noData
            }
        }
        
        return data
    }
}
