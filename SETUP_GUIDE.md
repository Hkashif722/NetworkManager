# NetworkService - Complete Setup Guide

## 📦 Package Structure

```
NetworkService/
├── Package.swift                           # SPM manifest
├── README.md                               # Main documentation
├── CHANGELOG.md                            # Version history
├── LICENSE                                 # MIT License
├── .gitignore                             # Git ignore rules
│
├── Sources/
│   └── NetworkService/
│       ├── ApiService.swift               # Main service class
│       │
│       ├── Models/
│       │   ├── APIError.swift             # Error types
│       │   ├── HTTPMethod.swift           # HTTP methods enum
│       │   └── EndpointModel.swift        # Endpoint protocol
│       │
│       ├── Middleware/
│       │   ├── NetworkMiddleware.swift    # Middleware protocol
│       │   ├── LoggingMiddleware.swift    # Request/response logging
│       │   ├── AuthenticationMiddleware.swift  # Token injection
│       │   └── RateLimitMiddleware.swift  # Rate limit handling
│       │
│       └── Validators/
│           ├── ResponseValidator.swift     # Validator protocol
│           ├── StatusCodeValidator.swift   # HTTP status validation
│           ├── EmptyResponseValidator.swift # Empty response check
│           ├── ContentTypeValidator.swift  # Content-type validation
│           └── CustomResponseValidator.swift # Custom validation
│
├── Tests/
│   └── NetworkServiceTests/
│       └── NetworkServiceTests.swift      # Unit tests
│
└── Examples/
    └── ExampleUsage.swift                 # Usage examples
```

## 🚀 Quick Start Guide

### 1. Create the Package

#### Option A: Using Terminal
```bash
# Create directory
mkdir NetworkService
cd NetworkService

# Initialize git
git init

# Copy all files from the generated structure above
```

#### Option B: Using Xcode
1. File > New > Package...
2. Name it "NetworkService"
3. Replace Package.swift with the provided one
4. Add all source files in the correct structure

### 2. Initialize Git Repository

```bash
cd NetworkService
git init
git add .
git commit -m "Initial commit - NetworkService v1.0.0"
```

### 3. Push to GitHub

```bash
# Create a new repository on GitHub first, then:
git remote add origin https://github.com/yourusername/NetworkService.git
git branch -M main
git push -u origin main
```

### 4. Create a Release

```bash
git tag 1.0.0
git push origin 1.0.0
```

## 📱 Integration in Your iOS App

### Step 1: Add Package Dependency

#### Using Xcode:
1. Open your Xcode project
2. Go to **File > Add Package Dependencies...**
3. Enter your repository URL: `https://github.com/yourusername/NetworkService.git`
4. Select version: 1.0.0
5. Click **Add Package**

#### Using Package.swift:
```swift
dependencies: [
    .package(url: "https://github.com/yourusername/NetworkService.git", from: "1.0.0")
]
```

### Step 2: Import and Configure

Create a NetworkManager in your app:

```swift
// NetworkManager.swift
import Foundation
import NetworkService

class NetworkManager {
    static let shared = NetworkManager()
    
    private init() {
        configureNetworkService()
    }
    
    private func configureNetworkService() {
        // Setup JSON decoder
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        ApiService.shared.setDecoder(decoder)
        
        // Setup authentication
        ApiService.shared.setAuthToken {
            return UserDefaults.standard.string(forKey: "authToken")
        }
        
        // Add custom headers middleware
        ApiService.shared.addMiddleware(CustomHeaderMiddleware())
    }
}

// Custom middleware for your app
struct CustomHeaderMiddleware: NetworkMiddleware {
    func prepare(request: URLRequest) throws -> URLRequest {
        var modifiedRequest = request
        modifiedRequest.setValue("iOS", forHTTPHeaderField: "X-Platform")
        modifiedRequest.setValue(Bundle.main.appVersion, forHTTPHeaderField: "X-App-Version")
        return modifiedRequest
    }
    
    func process(data: Data, response: HTTPURLResponse) throws -> Data {
        return data
    }
}
```

### Step 3: Initialize in AppDelegate or App

```swift
// For UIKit (AppDelegate)
@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        _ = NetworkManager.shared
        return true
    }
}

// For SwiftUI
@main
struct YourApp: App {
    init() {
        _ = NetworkManager.shared
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

### Step 4: Create Your API Endpoints

```swift
// APIEndpoints.swift
import NetworkService

enum APIEndpoints {
    static let baseURL = "https://api.yourapp.com"
}

struct UserEndpoint: EndpointModel {
    let path: String
    let method: HTTPMethod
    let headers: [String: String]?
    let baseURL: String
    
    static func login() -> UserEndpoint {
        UserEndpoint(
            path: "/auth/login",
            method: .post,
            headers: ["X-API-Key": "your-key"],
            baseURL: APIEndpoints.baseURL
        )
    }
    
    static func profile(userId: Int) -> UserEndpoint {
        UserEndpoint(
            path: "/users/\(userId)",
            method: .get,
            headers: nil,
            baseURL: APIEndpoints.baseURL
        )
    }
}
```

### Step 5: Make API Calls

```swift
// In your ViewModel or ViewController
Task {
    do {
        let user = try await ApiService.shared.requestGetHeader(
            type: User.self,
            model: UserEndpoint.profile(userId: 123)
        )
        print("User: \(user.name)")
    } catch let error as APIError {
        print("Error: \(error.localizedDescription)")
    }
}
```

## 🧪 Running Tests

```bash
# Run all tests
swift test

# Run with verbose output
swift test --verbose

# Run specific test
swift test --filter NetworkServiceTests
```

## 📝 Customization Examples

### Custom Error Response Format

If your API returns errors in a specific format:

```swift
struct CustomErrorValidator: ResponseValidator {
    func validate(data: Data, response: HTTPURLResponse) throws -> Data {
        struct ErrorResponse: Codable {
            let error: Bool
            let message: String
            let code: String
        }
        
        if response.statusCode >= 400,
           let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
            throw APIError.serverError(
                statusCode: response.statusCode,
                message: "\(errorResponse.code): \(errorResponse.message)"
            )
        }
        
        return data
    }
}

// Add to service
ApiService.shared.addValidator(CustomErrorValidator())
```

### Refresh Token Middleware

```swift
struct RefreshTokenMiddleware: NetworkMiddleware {
    func prepare(request: URLRequest) throws -> URLRequest {
        return request
    }
    
    func process(data: Data, response: HTTPURLResponse) throws -> Data {
        if response.statusCode == 401 {
            // Token expired, refresh it
            // This is a simplified example
            throw APIError.validationFailed("Token expired - refresh needed")
        }
        return data
    }
}
```

## 🔒 Best Practices

1. **Never commit sensitive data** - Keep API keys in environment variables
2. **Use Debug logging only** - Logging middleware is automatically disabled in release builds
3. **Handle errors gracefully** - Always provide user-friendly error messages
4. **Cache when appropriate** - Consider caching frequently accessed data
5. **Type safety first** - Always use Codable models for requests/responses

## 🐛 Troubleshooting

### Issue: Package not found
**Solution**: Make sure your Package.swift has the correct URL and version

### Issue: Decoder errors
**Solution**: Check your keyDecodingStrategy matches your API response format

### Issue: 401 Unauthorized
**Solution**: Verify your authentication token provider is returning a valid token

### Issue: Timeout errors
**Solution**: Increase timeout in URLSessionConfiguration if needed

## 📚 Additional Resources

- [Swift Package Manager Documentation](https://swift.org/package-manager/)
- [URLSession Documentation](https://developer.apple.com/documentation/foundation/urlsession)
- [Async/Await in Swift](https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html)

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## ✉️ Support

For issues, questions, or contributions, please open an issue on GitHub.
