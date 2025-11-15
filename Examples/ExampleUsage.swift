import SwiftUI
import NetworkService

// MARK: - Example Models

struct User: Codable {
    let id: Int
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

struct LeaderboardEntry: Codable {
    let rank: Int
    let username: String
    let score: Int
    let avatar: String?
}

struct LeaderboardPayload: Codable {
    let userId: String
    let period: String // "daily", "weekly", "monthly"
}

// MARK: - API Configuration

struct APIConfig {
    static let baseURL = "https://api.yourapp.com"
}

// MARK: - Endpoints

enum UserEndpoint: EndpointModel {
    case login
    case profile(userId: Int)
    case updateProfile(userId: Int)
    
    var path: String {
        switch self {
        case .login:
            return "/auth/login"
        case .profile(let userId):
            return "/users/\(userId)"
        case .updateProfile(let userId):
            return "/users/\(userId)"
        }
    }
    
    var method: HTTPMethod {
        switch self {
        case .login:
            return .post
        case .profile:
            return .get
        case .updateProfile:
            return .put
        }
    }
    
    var headers: [String: String]? {
        return [
            "X-App-Version": Bundle.main.appVersion ?? "1.0.0",
            "X-Platform": "iOS"
        ]
    }
    
    var baseURL: String {
        return APIConfig.baseURL
    }
}

enum LeaderboardEndpoint: EndpointModel {
    case rankings
    case userRank(userId: String)
    
    var path: String {
        switch self {
        case .rankings:
            return "/leaderboard/rankings"
        case .userRank(let userId):
            return "/leaderboard/user/\(userId)"
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
    
    var headers: [String: String]? {
        return nil
    }
    
    var baseURL: String {
        return APIConfig.baseURL
    }
}

// MARK: - Network Manager (Service Layer)

class NetworkManager {
    static let shared = NetworkManager()
    
    private init() {
        setupNetworkService()
    }
    
    private func setupNetworkService() {
        // Configure JSON decoder
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        ApiService.shared.setDecoder(decoder)
        
        // Configure JSON encoder
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        ApiService.shared.setEncoder(encoder)
        
        // Setup authentication
        ApiService.shared.setAuthToken { [weak self] in
            return self?.getAuthToken()
        }
        
        // Add custom validator
        ApiService.shared.addValidator(APIResponseValidator())
    }
    
    private func getAuthToken() -> String? {
        return UserDefaults.standard.string(forKey: "authToken")
    }
    
    // MARK: - User Methods
    
    func login(email: String, password: String) async throws -> LoginResponse {
        let payload = LoginPayload(email: email, password: password)
        
        let response = try await ApiService.shared.requestPostHeader(
            type: LoginResponse.self,
            model: UserEndpoint.login,
            payload: payload
        )
        
        // Save token
        UserDefaults.standard.set(response.token, forKey: "authToken")
        
        return response
    }
    
    func getUserProfile(userId: Int) async throws -> User {
        return try await ApiService.shared.requestGetHeader(
            type: User.self,
            model: UserEndpoint.profile(userId: userId)
        )
    }
    
    func updateUserProfile(userId: Int, name: String, email: String) async throws -> User {
        let payload = User(id: userId, name: name, email: email)
        
        return try await ApiService.shared.requestPutHeader(
            type: User.self,
            model: UserEndpoint.updateProfile(userId: userId),
            payload: payload
        )
    }
    
    // MARK: - Leaderboard Methods
    
    func getLeaderboard(userId: String, period: String) async throws -> [LeaderboardEntry] {
        let payload = LeaderboardPayload(userId: userId, period: period)
        
        return try await ApiService.shared.requestPostHeader(
            type: [LeaderboardEntry].self,
            model: LeaderboardEndpoint.rankings,
            payload: payload
        )
    }
}

// MARK: - Custom Validator

struct APIResponseValidator: ResponseValidator {
    func validate(data: Data, response: HTTPURLResponse) throws -> Data {
        // Check for specific API response format
        struct BaseResponse: Codable {
            let success: Bool
            let message: String?
        }
        
        if let baseResponse = try? JSONDecoder().decode(BaseResponse.self, from: data) {
            if !baseResponse.success {
                throw APIError.validationFailed(baseResponse.message ?? "Unknown error")
            }
        }
        
        return data
    }
}

// MARK: - SwiftUI Example View

struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var user: User?
    
    var body: some View {
        VStack(spacing: 20) {
            TextField("Email", text: $email)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
            
            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)
            
            Button("Login") {
                Task {
                    await login()
                }
            }
            .disabled(isLoading)
            
            if isLoading {
                ProgressView()
            }
            
            if let errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
            }
            
            if let user {
                Text("Welcome, \(user.name)!")
                    .foregroundColor(.green)
            }
        }
        .padding()
    }
    
    private func login() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let response = try await NetworkManager.shared.login(
                email: email,
                password: password
            )
            user = response.user
        } catch let error as APIError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "An unexpected error occurred"
        }
        
        isLoading = false
    }
}

// MARK: - UIKit Example

class LoginViewController: UIViewController {
    private let emailTextField = UITextField()
    private let passwordTextField = UITextField()
    private let loginButton = UIButton(type: .system)
    private let activityIndicator = UIActivityIndicatorView(style: .medium)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        // Setup UI components...
        loginButton.addTarget(self, action: #selector(loginTapped), for: .touchUpInside)
    }
    
    @objc private func loginTapped() {
        Task {
            await login()
        }
    }
    
    private func login() async {
        guard let email = emailTextField.text,
              let password = passwordTextField.text else { return }
        
        activityIndicator.startAnimating()
        loginButton.isEnabled = false
        
        do {
            let response = try await NetworkManager.shared.login(
                email: email,
                password: password
            )
            
            // Handle successful login
            await MainActor.run {
                print("Logged in as: \(response.user.name)")
                // Navigate to main screen
            }
        } catch let error as APIError {
            await MainActor.run {
                showError(error.localizedDescription)
            }
        } catch {
            await MainActor.run {
                showError("An unexpected error occurred")
            }
        }
        
        await MainActor.run {
            activityIndicator.stopAnimating()
            loginButton.isEnabled = true
        }
    }
    
    private func showError(_ message: String) {
        let alert = UIAlertController(
            title: "Error",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - Helper Extensions

extension Bundle {
    var appVersion: String? {
        return infoDictionary?["CFBundleShortVersionString"] as? String
    }
}

// MARK: - App Initialization

// Add this to your AppDelegate or App struct:
/*
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Initialize network manager
        _ = NetworkManager.shared
        
        return true
    }
}
*/
