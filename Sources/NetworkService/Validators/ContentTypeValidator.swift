import Foundation

/// Validator for response content type
public struct ContentTypeValidator: ResponseValidator {
    
    public let expectedContentTypes: [String]
    
    public init(expectedContentTypes: [String] = ["application/json", "text/plain"]) {
        self.expectedContentTypes = expectedContentTypes
    }
    
    public func validate(data: Data, response: HTTPURLResponse) throws -> Data {
        guard let contentType = response.value(forHTTPHeaderField: "Content-Type") else {
            return data
        }
        
        let isAccepted = expectedContentTypes.contains {
            contentType.lowercased().contains($0.lowercased())
        }
        
        guard isAccepted else {
            #if DEBUG
            print("❌ ContentTypeValidator rejected: '\(contentType)'")
            print("   Expected one of: \(expectedContentTypes)")
            #endif
            throw APIError.invalidResponse
        }
        
        return data
    }
}
