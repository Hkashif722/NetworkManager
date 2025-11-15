import Foundation

/// Validator for HTTP status codes
public struct StatusCodeValidator: ResponseValidator {
    
    public let acceptableStatusCodes: Range<Int>
    
    public init(acceptableStatusCodes: Range<Int> = 200..<300) {
        self.acceptableStatusCodes = acceptableStatusCodes
    }
    
    public func validate(data: Data, response: HTTPURLResponse) throws -> Data {
        guard acceptableStatusCodes.contains(response.statusCode) else {
            // Try to parse error message from response
            let errorMessage = parseErrorMessage(from: data)
            throw APIError.serverError(
                statusCode: response.statusCode,
                message: errorMessage
            )
        }
        return data
    }
    
    private func parseErrorMessage(from data: Data) -> String? {
        // Try to parse common error response formats
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            // Check common error message keys
            if let message = json["message"] as? String {
                return message
            }
            if let error = json["error"] as? String {
                return error
            }
            if let errorMessage = json["errorMessage"] as? String {
                return errorMessage
            }
        }
        return String(data: data, encoding: .utf8)
    }
}
