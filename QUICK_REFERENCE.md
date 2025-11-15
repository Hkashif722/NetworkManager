# NetworkService - Quick Reference Card

## 🚀 Installation

```swift
// In Package.swift
dependencies: [
    .package(url: "https://github.com/yourusername/NetworkService.git", from: "1.0.0")
]
```

## ⚡ Basic Usage

### 1. Import
```swift
import NetworkService
```

### 2. Create Endpoint
```swift
let endpoint = APIEndpoint(
    path: "/api/users",
    method: .get,
    baseURL: "https://api.example.com"
)
```

### 3. Make Request
```swift
let user = try await ApiService.shared.requestGetHeader(
    type: User.self,
    model: endpoint
)
```

## 📋 All HTTP Methods

```swift
// GET
let data = try await ApiService.shared.requestGetHeader(
    type: ResponseType.self,
    model: endpoint
)

// POST
let data = try await ApiService.shared.requestPostHeader(
    type: ResponseType.self,
    model: endpoint,
    payload: payload
)

// PUT
let data = try await ApiService.shared.requestPutHeader(
    type: ResponseType.self,
    model: endpoint,
    payload: payload
)

// DELETE
let data = try await ApiService.shared.requestDeleteHeader(
    type: ResponseType.self,
    model: endpoint
)

// PATCH
let data = try await ApiService.shared.requestPatchHeader(
    type: ResponseType.self,
    model: endpoint,
    payload: payload
)
```

## 🔧 Configuration

### Setup Authentication
```swift
ApiService.shared.setAuthToken {
    return UserDefaults.standard.string(forKey: "authToken")
}
```

### Custom JSON Decoder
```swift
let decoder = JSONDecoder()
decoder.keyDecodingStrategy = .convertFromSnakeCase
ApiService.shared.setDecoder(decoder)
```

### Add Middleware
```swift
ApiService.shared.addMiddleware(CustomMiddleware())
```

### Add Validator
```swift
ApiService.shared.addValidator(CustomValidator())
```

## 🛡️ Error Handling

```swift
do {
    let user = try await ApiService.shared.requestGetHeader(
        type: User.self,
        model: endpoint
    )
} catch APIError.invalidURL {
    // Handle invalid URL
} catch APIError.serverError(let code, let message) {
    // Handle server error
} catch APIError.decodingError {
    // Handle decoding error
} catch APIError.rateLimitExceeded(let retry) {
    // Handle rate limit
} catch {
    // Handle other errors
}
```

## 🎯 Common Patterns

### Custom Endpoint Enum
```swift
enum UserAPI: EndpointModel {
    case list
    case detail(id: Int)
    case create
    
    var path: String {
        switch self {
        case .list, .create: return "/users"
        case .detail(let id): return "/users/\(id)"
        }
    }
    
    var method: HTTPMethod {
        switch self {
        case .list, .detail: return .get
        case .create: return .post
        }
    }
    
    var baseURL: String { "https://api.example.com" }
    var headers: [String: String]? { nil }
}

// Usage
let users = try await ApiService.shared.requestGetHeader(
    type: [User].self,
    model: UserAPI.list
)
```

### Custom Middleware
```swift
struct CustomHeaderMiddleware: NetworkMiddleware {
    func prepare(request: URLRequest) throws -> URLRequest {
        var req = request
        req.setValue("value", forHTTPHeaderField: "X-Custom")
        return req
    }
    
    func process(data: Data, response: HTTPURLResponse) throws -> Data {
        return data
    }
}
```

### Custom Validator
```swift
struct CustomValidator: ResponseValidator {
    func validate(data: Data, response: HTTPURLResponse) throws -> Data {
        // Your validation logic
        return data
    }
}
```

## 📱 SwiftUI Integration

```swift
struct MyView: View {
    @State private var data: [Item] = []
    @State private var isLoading = false
    
    var body: some View {
        List(data) { item in
            Text(item.name)
        }
        .task {
            await loadData()
        }
    }
    
    func loadData() async {
        isLoading = true
        do {
            data = try await ApiService.shared.requestGetHeader(
                type: [Item].self,
                model: endpoint
            )
        } catch {
            print(error)
        }
        isLoading = false
    }
}
```

## 🎨 UIKit Integration

```swift
class MyViewController: UIViewController {
    func loadData() {
        Task {
            do {
                let data = try await ApiService.shared.requestGetHeader(
                    type: [Item].self,
                    model: endpoint
                )
                
                await MainActor.run {
                    // Update UI
                }
            } catch {
                await MainActor.run {
                    // Show error
                }
            }
        }
    }
}
```

## 🔑 Your Specific Use Case

```swift
// Define your models
struct GamificationDashboardDataModel {
    struct LeaderBoardResponseModel {
        struct RankingResponse: Codable {
            let rank: Int
            let score: Int
            // ... other fields
        }
    }
}

// Create endpoint
let model = APIEndpoint(
    path: "/api/leaderboard",
    method: .post,
    baseURL: "https://api.yourapp.com"
)

// Make request - EXACTLY as you wanted!
let response = try await ApiService.shared.requestPostHeader(
    type: GamificationDashboardDataModel.LeaderBoardResponseModel.RankingResponse.self,
    model: model,
    payload: payload
)
```

## 💡 Pro Tips

1. **Configure once** - Setup in AppDelegate/App init
2. **Type safety** - Always use Codable models
3. **Error handling** - Always catch and handle errors
4. **Logging** - Auto-enabled in DEBUG builds
5. **Testing** - Run `swift test` regularly

## 📚 Files to Check

- `README.md` - Full documentation
- `SETUP_GUIDE.md` - Integration guide
- `Examples/ExampleUsage.swift` - Common patterns
- `Examples/GamificationExample.swift` - Your use case

## 🆘 Common Issues

**Issue:** Decoding errors  
**Fix:** Check `keyDecodingStrategy` matches API

**Issue:** 401 errors  
**Fix:** Verify auth token provider

**Issue:** Timeout  
**Fix:** Increase timeout in configuration

---

**Version:** 1.0.0 | **License:** MIT
