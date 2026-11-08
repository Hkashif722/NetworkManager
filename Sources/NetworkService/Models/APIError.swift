import Foundation

/// Errors that can occur during network requests
public enum APIError: Error {
    // MARK: - Request Errors
    case invalidURL
    case invalidResponse
    case networkError(Error)
    case decodingError(Error)
    case noData
    
    // MARK: - Specific HTTP Errors (with context)
    case badRequest([String: Any], rawJSON: String)              // 400
    case unauthorized                                            // 401, 413
    case forbidden                                               // 403
    case notFound                                                // 404
    case encodingFailed
    case resourceGone([String: Any], rawJSON: String)            // 410
    case unprocessableEntity([String: Any], rawJSON: String)     // 422
    case tooManyRequests                                         // 429
    
    //MARK: Generic message error
    case customError(message: String)
    // MARK: - Generic/Fallback Errors
    case serverError(statusCode: Int, message: String?)          // Generic server error
    case rateLimitExceeded(retryAfter: String?)                  // Rate limiting
    case validationFailed(String)                                // Client-side validation
    case unknownError                                            // Catch-all
    
    // MARK: - Localized Description
    
    public var localizedDescription: String {
        switch self {
        // Request errors
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Decoding error: \(error.localizedDescription)"
        case .noData:
            return "No data received"
            
        // Specific HTTP errors
        case .badRequest(let dict, _):
            return dict["message"] as? String ?? "Bad request (400)"
        case .unauthorized:
            return "Unauthorized access (401)"
        case .forbidden:
            return "Access forbidden (403)"
        case .notFound:
            return "Resource not found (404)"
        case .resourceGone(let dict, _):
            return dict["message"] as? String ?? "Resource no longer available (410)"
        case .unprocessableEntity(let dict, _):
            return dict["message"] as? String ?? "Unprocessable entity (422)"
        case .tooManyRequests:
            return "Too many requests (429). Please try again later."
        case .encodingFailed:
            return "Failed to encode parameters for the request"
            
        case .customError(let message):
            return message
            
        // Generic/Fallback errors
        case .serverError(let statusCode, let message):
            return "Server error (\(statusCode)): \(message ?? "Unknown error")"
        case .rateLimitExceeded(let retryAfter):
            if let retry = retryAfter {
                return "Rate limit exceeded. Retry after: \(retry)"
            }
            return "Rate limit exceeded"
        case .validationFailed(let message):
            return "Validation failed: \(message)"
        case .unknownError:
            return "Unknown error occurred"
        }
    }
    
    // MARK: - HTTP Status Code
    
    /// Returns the HTTP status code if applicable
    public var statusCode: Int? {
        switch self {
        case .badRequest:
            return 400
        case .unauthorized:
            return 401
        case .forbidden:
            return 403
        case .notFound:
            return 404
        case .resourceGone:
            return 410
        case .unprocessableEntity:
            return 422
        case .tooManyRequests:
            return 429
        case .serverError(let code, _):
            return code
        default:
            return nil
        }
    }
    
    // MARK: - User-Facing Message
    
    /// Returns a user-friendly error message
    public var userMessage: String {
        switch self {
        case .networkError:
            return "Please check your internet connection and try again."
        case .unauthorized:
            return "Please log in to continue."
        case .forbidden:
            return "You don't have permission to access this resource."
        case .notFound:
            return "The requested resource could not be found."
        case .tooManyRequests, .rateLimitExceeded:
            return "Too many requests. Please wait a moment and try again."
        case .serverError:
            return "Something went wrong on our end. Please try again later."
        case .badRequest(let dict, _):
            return dict["message"] as? String ?? "Invalid request. Please check your input."
        case .encodingFailed:
            return "Something went wrong while preparing your request. Please try again."
        case .unprocessableEntity(let dict, _):
            return dict["message"] as? String ?? "Please check your input and try again."
        case .validationFailed(let message):
            return message
        default:
            return "An error occurred. Please try again."
        }
    }
    
    // MARK: - Is Retryable
    
    /// Indicates if the request should be retried
    public var isRetryable: Bool {
        switch self {
        case .networkError, .serverError, .tooManyRequests, .rateLimitExceeded:
            return true
        case .unauthorized, .forbidden, .notFound, .badRequest, .unprocessableEntity:
            return false
        default:
            return false
        }
    }
    
    // MARK: - Requires Authentication
    
    /// Indicates if the error is authentication-related
    public var requiresAuthentication: Bool {
        switch self {
        case .unauthorized:
            return true
        default:
            return false
        }
    }
}

// MARK: - CustomNSError (for better Objective-C interop)

extension APIError: CustomNSError {
    public static var errorDomain: String {
        return "com.yourapp.api"
    }
    
    public var errorCode: Int {
        return statusCode ?? -1
    }
    
    public var errorUserInfo: [String: Any] {
        var userInfo: [String: Any] = [
            NSLocalizedDescriptionKey: localizedDescription,
            NSLocalizedFailureReasonErrorKey: userMessage
        ]
        
        // Add raw JSON for debugging if available
        switch self {
        case .badRequest(_, let rawJSON),
             .resourceGone(_, let rawJSON),
             .unprocessableEntity(_, let rawJSON):
            userInfo["rawJSON"] = rawJSON
        default:
            break
        }
        
        return userInfo
    }
}

// MARK: - Equatable (for testing)

extension APIError: Equatable {
    public static func == (lhs: APIError, rhs: APIError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidURL, .invalidURL),
             (.invalidResponse, .invalidResponse),
             (.noData, .noData),
             (.unauthorized, .unauthorized),
             (.forbidden, .forbidden),
             (.notFound, .notFound),
             (.tooManyRequests, .tooManyRequests),
             (.unknownError, .unknownError):
            return true
        case (.networkError(let lhsError), .networkError(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        case (.decodingError(let lhsError), .decodingError(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        case (.customError(let lhsMsg), .customError(let rhsMsg)):
            return lhsMsg == rhsMsg
        case (.serverError(let lhsCode, let lhsMsg), .serverError(let rhsCode, let rhsMsg)):
            return lhsCode == rhsCode && lhsMsg == rhsMsg
        case (.validationFailed(let lhsMsg), .validationFailed(let rhsMsg)):
            return lhsMsg == rhsMsg
        case (.rateLimitExceeded(let lhsRetry), .rateLimitExceeded(let rhsRetry)):
            return lhsRetry == rhsRetry
        case (.badRequest(_, let lhsJSON), .badRequest(_, let rhsJSON)):
            return lhsJSON == rhsJSON
        case (.resourceGone(_, let lhsJSON), .resourceGone(_, let rhsJSON)):
            return lhsJSON == rhsJSON
        case (.unprocessableEntity(_, let lhsJSON), .unprocessableEntity(_, let rhsJSON)):
            return lhsJSON == rhsJSON
        default:
            return false
        }
    }
}
