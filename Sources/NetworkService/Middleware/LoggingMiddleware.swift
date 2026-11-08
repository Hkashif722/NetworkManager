import Foundation

/// Middleware for logging network requests and responses
public struct LoggingMiddleware: NetworkMiddleware {
    
    public enum LogLevel {
        case none
        case basic
        case detailed
    }
    
    public let logLevel: LogLevel
    
    public init(logLevel: LogLevel = .basic) {
        self.logLevel = logLevel
    }
    
    public func prepare(request: URLRequest) throws -> URLRequest {
        if logLevel != .none {
            print("🌐 Request: \(request.httpMethod ?? "") \(request.url?.absoluteString ?? "")")
            
            if logLevel == .detailed {
                if let headers = request.allHTTPHeaderFields {
                    print("📋 Headers: \(headers)")
                }
                if let body = request.httpBody,
                   let bodyString = String(data: body, encoding: .utf8) {
                    print("📦 Body: \(bodyString)")
                }
            }
        }
        return request
    }
    
    public func process(data: Data, response: HTTPURLResponse) throws -> Data {
        if logLevel != .none {
            print("✅ Response: \(response.statusCode) from \(response.url?.absoluteString ?? "")")
            
            if logLevel == .detailed {
                if let responseString = String(data: data, encoding: .utf8) {
                    print("📥 Response Data: \(responseString)")
                }
            }
        }
        return data
    }
}
