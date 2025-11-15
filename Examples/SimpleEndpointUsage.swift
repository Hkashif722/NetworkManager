import Foundation
import NetworkService

// MARK: - STEP 1: Configure Once (in AppDelegate or App init)

class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        
        // ✅ Configure API settings once
        APIConfiguration.shared.configure(
            baseURL: "https://api.yourapp.com",
            apiKey: "sk_live_abc123xyz456",  // Your API Key
            apiKeyHeaderName: "X-API-Key",   // Optional: defaults to "X-API-Key"
            defaultHeaders: [
                "X-Platform": "iOS",
                "X-App-Version": Bundle.main.appVersion ?? "1.0.0"
            ]
        )
        
        // ✅ Setup Bearer Token (for user authentication)
        ApiService.shared.setAuthToken {
            return KeychainManager.getToken()
            // OR: return UserDefaults.standard.string(forKey: "authToken")
        }
        
        // ✅ Setup JSON decoder if needed
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        ApiService.shared.setDecoder(decoder)
        
        return true
    }
}

// MARK: - STEP 2: Define Your Endpoints (Super Simple!)

// ✅ OPTION 1: Enum-based (Recommended for multiple endpoints)
enum UserAPI: SimpleEndpoint {
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
    
    // No need to define baseURL, headers - they come from global config!
}

// ✅ OPTION 2: Struct-based (For single/simple endpoints)
struct LoginEndpoint: SimpleEndpoint {
    var path: String { "/auth/login" }
    var method: HTTPMethod { .post }
}

struct LogoutEndpoint: SimpleEndpoint {
    var path: String { "/auth/logout" }
    var method: HTTPMethod { .post }
}

// ✅ OPTION 3: Custom headers for specific endpoints
struct UploadEndpoint: SimpleEndpoint {
    var path: String { "/api/upload" }
    var method: HTTPMethod { .post }
    
    // Override default headers for this endpoint only
    var customHeaders: [String: String]? {
        return [
            "Content-Type": "multipart/form-data"
        ]
    }
}

// ✅ OPTION 4: Different base URL for specific endpoint
struct AnalyticsEndpoint: SimpleEndpoint {
    var path: String { "/events" }
    var method: HTTPMethod { .post }
    
    // Use different base URL just for this endpoint
    var baseURL: String? { "https://analytics.yourapp.com" }
}

// MARK: - STEP 3: Make API Calls (Super Clean!)

// MARK: - Example Models
struct User: Codable {
    let id: Int
    let name: String
    let email: String
}

struct CreateUserPayload: Codable {
    let name: String
    let email: String
}

struct LoginPayload: Codable {
    let email: String
    let password: String
}

struct LoginResponse: Codable {
    let token: String
    let user: User
}

// MARK: - Usage Examples

class UserService {
    
    // ✅ GET Request - Super Simple!
    func getUsers() async throws -> [User] {
        return try await ApiService.shared.get(
            UserAPI.list,
            type: [User].self
        )
    }
    
    // ✅ GET with ID
    func getUser(id: Int) async throws -> User {
        return try await ApiService.shared.get(
            UserAPI.detail(id: id),
            type: User.self
        )
    }
    
    // ✅ POST Request
    func createUser(name: String, email: String) async throws -> User {
        let payload = CreateUserPayload(name: name, email: email)
        
        return try await ApiService.shared.post(
            UserAPI.create,
            payload: payload,
            type: User.self
        )
    }
    
    // ✅ PUT Request
    func updateUser(id: Int, name: String, email: String) async throws -> User {
        let payload = CreateUserPayload(name: name, email: email)
        
        return try await ApiService.shared.put(
            UserAPI.update(id: id),
            payload: payload,
            type: User.self
        )
    }
    
    // ✅ DELETE Request
    func deleteUser(id: Int) async throws -> User {
        return try await ApiService.shared.delete(
            UserAPI.delete(id: id),
            type: User.self
        )
    }
    
    // ✅ Login (saves token)
    func login(email: String, password: String) async throws -> LoginResponse {
        let payload = LoginPayload(email: email, password: password)
        
        let response = try await ApiService.shared.post(
            LoginEndpoint(),
            payload: payload,
            type: LoginResponse.self
        )
        
        // Save token
        KeychainManager.saveToken(response.token)
        
        return response
    }
}

// MARK: - Your Gamification Use Case - SIMPLIFIED!

struct GamificationDashboard {
    struct LeaderboardResponse: Codable {
        let rank: Int
        let score: Int
        let username: String
        let level: Int
    }
}

struct LeaderboardPayload: Codable {
    let userId: String
    let period: String
}

// ✅ Define endpoint
enum LeaderboardAPI: SimpleEndpoint {
    case rankings
    case userRank(userId: String)
    
    var path: String {
        switch self {
        case .rankings:
            return "/api/leaderboard/rankings"
        case .userRank(let userId):
            return "/api/leaderboard/user/\(userId)"
        }
    }
    
    var method: HTTPMethod {
        switch self {
        case .rankings:
            return .post
        case .userRank:
            return .get
        }
    }
    
    // No headers needed! API key comes from global config
}

// ✅ Use it - SUPER CLEAN!
class LeaderboardService {
    
    func getRankings(userId: String, period: String) async throws -> GamificationDashboard.LeaderboardResponse {
        let payload = LeaderboardPayload(userId: userId, period: period)
        
        // Look how clean this is! No headers, no baseURL, nothing!
        return try await ApiService.shared.post(
            LeaderboardAPI.rankings,
            payload: payload,
            type: GamificationDashboard.LeaderboardResponse.self
        )
    }
    
    func getUserRank(userId: String) async throws -> GamificationDashboard.LeaderboardResponse {
        return try await ApiService.shared.get(
            LeaderboardAPI.userRank(userId: userId),
            type: GamificationDashboard.LeaderboardResponse.self
        )
    }
}

// MARK: - SwiftUI Example

import SwiftUI

struct LeaderboardView: View {
    @State private var rankings: GamificationDashboard.LeaderboardResponse?
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        VStack {
            if isLoading {
                ProgressView()
            } else if let rankings {
                VStack(spacing: 8) {
                    Text("Rank: #\(rankings.rank)")
                        .font(.title)
                    Text("Score: \(rankings.score)")
                    Text("Level: \(rankings.level)")
                }
            } else if let errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
            }
        }
        .task {
            await loadRankings()
        }
    }
    
    func loadRankings() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // ✅ Super clean API call!
            rankings = try await LeaderboardService().getRankings(
                userId: "user123",
                period: "weekly"
            )
        } catch let error as APIError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "Unknown error"
        }
    }
}

// MARK: - Advanced: Multiple Environments

extension APIConfiguration {
    enum Environment {
        case development
        case staging
        case production
        
        var baseURL: String {
            switch self {
            case .development:
                return "https://dev-api.yourapp.com"
            case .staging:
                return "https://staging-api.yourapp.com"
            case .production:
                return "https://api.yourapp.com"
            }
        }
        
        var apiKey: String {
            switch self {
            case .development:
                return "dev_key_123"
            case .staging:
                return "staging_key_456"
            case .production:
                return "prod_key_789"
            }
        }
    }
    
    func configure(environment: Environment) {
        self.configure(
            baseURL: environment.baseURL,
            apiKey: environment.apiKey,
            defaultHeaders: [
                "X-Platform": "iOS",
                "X-Environment": "\(environment)"
            ]
        )
    }
}

// Usage in AppDelegate:
/*
#if DEBUG
APIConfiguration.shared.configure(environment: .development)
#else
APIConfiguration.shared.configure(environment: .production)
#endif
*/

// MARK: - Helper Extensions

extension Bundle {
    var appVersion: String? {
        return infoDictionary?["CFBundleShortVersionString"] as? String
    }
}

// Simple Keychain Manager
class KeychainManager {
    static func saveToken(_ token: String) {
        UserDefaults.standard.set(token, forKey: "authToken")
        // In production, use Keychain instead
    }
    
    static func getToken() -> String? {
        return UserDefaults.standard.string(forKey: "authToken")
    }
    
    static func clearToken() {
        UserDefaults.standard.removeObject(forKey: "authToken")
    }
}

// MARK: - Comparison: Before vs After

/*
// ❌ BEFORE (with old approach):
let endpoint = APIEndpoint(
    path: "/api/leaderboard",
    method: .post,
    baseURL: "https://api.yourapp.com",
    headers: [
        "X-API-Key": "sk_live_abc123xyz",
        "Content-Type": "application/json",
        "X-Platform": "iOS"
    ]
)

let response = try await ApiService.shared.requestPostHeader(
    type: GamificationDashboard.LeaderboardResponse.self,
    model: endpoint,
    payload: payload
)

// ✅ AFTER (with SimpleEndpoint):
enum LeaderboardAPI: SimpleEndpoint {
    case rankings
    var path: String { "/api/leaderboard" }
    var method: HTTPMethod { .post }
}

let response = try await ApiService.shared.post(
    LeaderboardAPI.rankings,
    payload: payload,
    type: GamificationDashboard.LeaderboardResponse.self
)

// Headers, baseURL, API Key all handled automatically! 🎉
*/
