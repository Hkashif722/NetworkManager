import Foundation

/// Validator for response content type
public struct ContentTypeValidator: ResponseValidator {
    
    public let expectedContentType: String
    
    public init(expectedContentType: String = "application/json") {
        self.expectedContentType = expectedContentType
    }
    
    public func validate(data: Data, response: HTTPURLResponse) throws -> Data {
        guard let contentType = response.value(forHTTPHeaderField: "Content-Type") else {
            // If no content type, skip validation
            return data
        }
        
        guard contentType.lowercased().contains(expectedContentType.lowercased()) else {
            throw APIError.invalidResponse
        }
        
        return data
    }
}
