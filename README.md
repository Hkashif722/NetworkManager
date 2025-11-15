# NetworkService

A powerful, flexible, and type-safe networking layer for Swift applications built with URLSession. This package provides a clean API for making HTTP requests with support for middleware, validators, and comprehensive error handling.

## Features

✅ **Type-Safe API** - Fully generic with Codable support  
✅ **Async/Await** - Modern Swift concurrency  
✅ **Middleware System** - Extensible request/response processing  
✅ **Response Validation** - Chainable validators for data integrity  
✅ **Error Handling** - Comprehensive error types with detailed messages  
✅ **Automatic Logging** - Built-in request/response logging (DEBUG only)  
✅ **Authentication** - Easy token injection via middleware  
✅ **Rate Limiting** - Built-in 429 response handling  
✅ **Customizable** - Custom encoders, decoders, and timeout configuration  

## Requirements

- iOS 15.0+ / macOS 12.0+ / tvOS 15.0+ / watchOS 8.0+
- Swift 5.9+
- Xcode 15.0+

## Installation

### Swift Package Manager

Add NetworkService to your project using Xcode:

1. In Xcode, select **File** > **Add Package Dependencies...**
2. Enter the repository URL: `https://github.com/yourusername/NetworkService.git`
3. Select the version you want to use
4. Click **Add Package**

Or add it to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/NetworkService.git", from: "1.0.0")
]
```

Then add it to your target:

```swift
targets: [
    .target(
        name: "YourApp",
        dependencies: ["NetworkService"]
    )
]
```

## Quick Start

### 1. Define Your Models

```swift
import NetworkService

// Response model
struct User: Codable {
    let id: Int
    let name: String
    let email: String
}

// Request payload
struct LoginPayload: Codable {
    let email: String
    let password: String
}
```

### 2. Create an Endpoint

```swift
let endpoint = APIEndpoint(
    path: "/api/users/login",
    method: .post,
    baseURL: "https://api.example.com",
    headers: [
        "X-API-Key": "your-api-key"
    ]
)
```

### 3. Make a Request

```swift
Task {
    do {
        let payload = LoginPayload(email: "user@example.com", password: "password")
        let user = try await ApiService.shared.requestPostHeader(
            type: User.self,
            model: endpoint,
            payload: payload
        )
        print("Logged in as: \(user.name)")
    } catch let error as APIError {
        print("API Error: \(error.localizedDescription)")
    }
}
```

## Usage Examples

### GET Request

```swift
let endpoint = APIEndpoint(
    path: "/api/users/123",
    method: .get,
    baseURL: "https://api.example.com"
)

let user = try await ApiService.shared.requestGetHeader(
    type: User.self,
    model: endpoint
)
```

### POST Request

```swift
let endpoint = APIEndpoint(
    path: "/api/users",
    method: .post,
    baseURL: "https://api.example.com"
)

let payload = CreateUserPayload(name: "John", email: "john@example.com")
let user = try await ApiService.shared.requestPostHeader(
    type: User.self,
    model: endpoint,
    payload: payload
)
```

### PUT Request

```swift
let endpoint = APIEndpoint(
    path: "/api/users/123",
    method: .put,
    baseURL: "https://api.example.com"
)

let payload = UpdateUserPayload(name: "John Updated")
let user = try await ApiService.shared.requestPutHeader(
    type: User.self,
    model: endpoint,
    payload: payload
)
```

### DELETE Request

```swift
let endpoint = APIEndpoint(
    path: "/api/users/123",
    method: .delete,
    baseURL: "https://api.example.com"
)

let response = try await ApiService.shared.requestDeleteHeader(
    type: DeleteResponse.self,
    model: endpoint
)
```

## Middleware

### Adding Authentication

```swift
// Set up once in your app initialization
ApiService.shared.setAuthToken {
    return UserDefaults.standard.string(forKey: "authToken")
}
```

### Custom Middleware

```swift
struct CustomHeaderMiddleware: NetworkMiddleware {
    func prepare(request: URLRequest) throws -> URLRequest {
        var modifiedRequest = request
        modifiedRequest.setValue("iOS", forHTTPHeaderField: "X-Platform")
        modifiedRequest.setValue(UIDevice.current.systemVersion, forHTTPHeaderField: "X-OS-Version")
        return modifiedRequest
    }
    
    func process(data: Data, response: HTTPURLResponse) throws -> Data {
        return data
    }
}

ApiService.shared.addMiddleware(CustomHeaderMiddleware())
```

### Logging Middleware

```swift
// Already included by default in DEBUG builds
// To add custom logging:
let loggingMiddleware = LoggingMiddleware(logLevel: .detailed)
ApiService.shared.addMiddleware(loggingMiddleware)
```

## Validators

### Default Validators

The service comes with three default validators:
- **StatusCodeValidator** - Validates HTTP status codes (default: 200-299)
- **EmptyResponseValidator** - Checks for empty responses
- **ContentTypeValidator** - Validates content-type headers

### Custom Validators

```swift
struct CustomValidator: ResponseValidator {
    func validate(data: Data, response: HTTPURLResponse) throws -> Data {
        // Parse response to check for success flag
        struct BaseResponse: Codable {
            let success: Bool
            let message: String?
        }
        
        if let baseResponse = try? JSONDecoder().decode(BaseResponse.self, from: data),
           !baseResponse.success {
            throw APIError.validationFailed(baseResponse.message ?? "Unknown error")
        }
        
        return data
    }
}

ApiService.shared.addValidator(CustomValidator())
```

### Using CustomResponseValidator

```swift
let validator = CustomResponseValidator { data, response in
    // Your custom validation logic
    guard response.statusCode == 200 else {
        throw APIError.serverError(statusCode: response.statusCode, message: nil)
    }
    return data
}

ApiService.shared.addValidator(validator)
```

## Error Handling

```swift
do {
    let user = try await ApiService.shared.requestGetHeader(
        type: User.self,
        model: endpoint
    )
} catch APIError.invalidURL {
    print("Invalid URL")
} catch APIError.serverError(let statusCode, let message) {
    print("Server error \(statusCode): \(message ?? "Unknown")")
} catch APIError.decodingError(let error) {
    print("Failed to decode response: \(error)")
} catch APIError.rateLimitExceeded(let retryAfter) {
    print("Rate limited. Retry after: \(retryAfter ?? "unknown")")
} catch {
    print("Unexpected error: \(error)")
}
```

## Configuration

### Custom JSON Decoder

```swift
let decoder = JSONDecoder()
decoder.keyDecodingStrategy = .convertFromSnakeCase
decoder.dateDecodingStrategy = .iso8601
ApiService.shared.setDecoder(decoder)
```

### Custom JSON Encoder

```swift
let encoder = JSONEncoder()
encoder.keyEncodingStrategy = .convertToSnakeCase
encoder.dateEncodingStrategy = .iso8601
ApiService.shared.setEncoder(encoder)
```

## Advanced Usage

### Creating Custom Endpoint Types

```swift
enum UserEndpoint: EndpointModel {
    case list
    case detail(id: Int)
    case create
    case update(id: Int)
    case delete(id: Int)
    
    var path: String {
        switch self {
        case .list, .create:
            return "/api/users"
        case .detail(let id), .update(let id), .delete(let id):
            return "/api/users/\(id)"
        }
    }
    
    var method: HTTPMethod {
        switch self {
        case .list, .detail:
            return .get
        case .create:
            return .post
        case .update:
            return .put
        case .delete:
            return .delete
        }
    }
    
    var headers: [String: String]? {
        return ["X-API-Key": "your-key"]
    }
    
    var baseURL: String {
        return "https://api.example.com"
    }
}

// Usage
let users = try await ApiService.shared.requestGetHeader(
    type: [User].self,
    model: UserEndpoint.list
)
```

### Handling Wrapped Responses

If your API wraps responses in a standard format:

```swift
struct WrappedResponse<T: Codable>: Codable {
    let data: T
    let success: Bool
    let message: String?
}

// Create a validator to unwrap
struct ResponseUnwrapMiddleware: NetworkMiddleware {
    func prepare(request: URLRequest) throws -> URLRequest {
        return request
    }
    
    func process(data: Data, response: HTTPURLResponse) throws -> Data {
        struct Wrapper: Codable {
            let data: Data
        }
        
        if let wrapped = try? JSONDecoder().decode(Wrapper.self, from: data) {
            return wrapped.data
        }
        
        return data
    }
}

ApiService.shared.addMiddleware(ResponseUnwrapMiddleware())
```

## Testing

The package includes comprehensive unit tests. Run them using:

```bash
swift test
```

## Best Practices

1. **Configure Once** - Set up authentication and custom middleware in your app initialization
2. **Type Safety** - Always use strongly-typed models for requests and responses
3. **Error Handling** - Always handle errors appropriately in your UI
4. **Logging** - Use logging middleware only in DEBUG builds
5. **Reusability** - Create enum-based endpoints for better organization

## License

MIT License - See LICENSE file for details

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Author

Your Name - [@yourhandle](https://twitter.com/yourhandle)
