import Foundation

/// Custom validator that accepts a closure for validation logic
public struct CustomResponseValidator: ResponseValidator {
    
    private let validation: (Data, HTTPURLResponse) throws -> Data
    
    public init(validation: @escaping (Data, HTTPURLResponse) throws -> Data) {
        self.validation = validation
    }
    
    public func validate(data: Data, response: HTTPURLResponse) throws -> Data {
        return try validation(data, response)
    }
}
