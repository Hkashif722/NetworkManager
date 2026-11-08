import Foundation

/// Validator for HTTP status codes with specific error mapping
public struct StatusCodeValidator: ResponseValidator {
    
    public init() {}
    
    public func validate(data: Data, response: HTTPURLResponse) throws -> Data {
        let statusCode = response.statusCode
        
        guard statusCode < 400 else {
            let jsonString = String(data: data, encoding: .utf8) ?? ""
            let jsonDict = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
            
            print("❌ HTTP \(statusCode): \(jsonString)")
            
            throw mapStatusCodeToError(statusCode, jsonDict: jsonDict, jsonString: jsonString)
        }
        
        return data
    }
    
    private func mapStatusCodeToError(_ statusCode: Int, jsonDict: [String: Any], jsonString: String) -> APIError {
        switch statusCode {
        case 400:
            return .badRequest(jsonDict, rawJSON: jsonString)
        case 401, 413:
            return .unauthorized
        case 410:
            return .resourceGone(jsonDict, rawJSON: jsonString)
        default:
            let serverMessage = (jsonDict["message"] as? String)
                ?? (jsonDict["description"] as? String)
                ?? (jsonDict["error"] as? String) 
                ?? (jsonString.isEmpty ? nil : jsonString)
            return .serverError(statusCode: statusCode, message: serverMessage)
        }
    }
}
