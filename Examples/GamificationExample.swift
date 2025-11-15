import Foundation
import NetworkService

// MARK: - Your Specific Use Case Example
// This demonstrates how to use NetworkService with your GamificationDashboardDataModel

// MARK: - Models (Your existing models)

struct GamificationDashboardDataModel {
    struct LeaderBoardResponseModel {
        struct RankingResponse: Codable {
            let rank: Int
            let score: Int
            let username: String
            let level: Int
            let badge: String?
            let avatar: String?
            let points: Int
        }
        
        struct LeaderboardList: Codable {
            let rankings: [RankingResponse]
            let totalUsers: Int
            let currentPage: Int
            let totalPages: Int
        }
    }
}

// MARK: - Request Payload

struct LeaderboardRequestPayload: Codable {
    let userId: String
    let period: String // "daily", "weekly", "monthly", "allTime"
    let page: Int
    let limit: Int
}

// MARK: - API Configuration

struct GamificationAPIConfig {
    static let baseURL = "https://api.yourapp.com"
}

// MARK: - Endpoint Definition

struct LeaderboardEndpoint: EndpointModel {
    let path: String
    let method: HTTPMethod
    let headers: [String: String]?
    let baseURL: String
    
    static func getRankings() -> LeaderboardEndpoint {
        LeaderboardEndpoint(
            path: "/api/v1/leaderboard/rankings",
            method: .post,
            headers: [
                "X-API-Key": "your-api-key-here",
                "Content-Type": "application/json"
            ],
            baseURL: GamificationAPIConfig.baseURL
        )
    }
    
    static func getUserRanking(userId: String) -> LeaderboardEndpoint {
        LeaderboardEndpoint(
            path: "/api/v1/leaderboard/user/\(userId)",
            method: .get,
            headers: nil,
            baseURL: GamificationAPIConfig.baseURL
        )
    }
}

// MARK: - Usage Example - EXACTLY as you wanted

class GamificationService {
    static let shared = GamificationService()
    
    private init() {}
    
    // MARK: - This is EXACTLY how you wanted to call it!
    func fetchLeaderboard(userId: String, period: String = "weekly") async throws -> GamificationDashboardDataModel.LeaderBoardResponseModel.RankingResponse {
        
        let model = LeaderboardEndpoint.getRankings()
        
        let payload = LeaderboardRequestPayload(
            userId: userId,
            period: period,
            page: 1,
            limit: 50
        )
        
        // ✅ THIS IS YOUR EXACT API CALL PATTERN
        let response = try await ApiService.shared.requestPostHeader(
            type: GamificationDashboardDataModel.LeaderBoardResponseModel.RankingResponse.self,
            model: model,
            payload: payload
        )
        
        return response
    }
    
    // Alternative: Fetch full leaderboard list
    func fetchLeaderboardList(userId: String, period: String = "weekly") async throws -> GamificationDashboardDataModel.LeaderBoardResponseModel.LeaderboardList {
        
        let model = LeaderboardEndpoint.getRankings()
        
        let payload = LeaderboardRequestPayload(
            userId: userId,
            period: period,
            page: 1,
            limit: 50
        )
        
        let response = try await ApiService.shared.requestPostHeader(
            type: GamificationDashboardDataModel.LeaderBoardResponseModel.LeaderboardList.self,
            model: model,
            payload: payload
        )
        
        return response
    }
    
    // Get single user ranking
    func fetchUserRanking(userId: String) async throws -> GamificationDashboardDataModel.LeaderBoardResponseModel.RankingResponse {
        
        let model = LeaderboardEndpoint.getUserRanking(userId: userId)
        
        let response = try await ApiService.shared.requestGetHeader(
            type: GamificationDashboardDataModel.LeaderBoardResponseModel.RankingResponse.self,
            model: model
        )
        
        return response
    }
}

// MARK: - SwiftUI Example Usage

import SwiftUI

struct LeaderboardView: View {
    @State private var rankings: [GamificationDashboardDataModel.LeaderBoardResponseModel.RankingResponse] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView("Loading leaderboard...")
                } else if let errorMessage {
                    VStack {
                        Text("Error")
                            .font(.headline)
                        Text(errorMessage)
                            .foregroundColor(.red)
                        Button("Retry") {
                            Task {
                                await loadLeaderboard()
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                } else {
                    List(rankings, id: \.rank) { ranking in
                        LeaderboardRowView(ranking: ranking)
                    }
                }
            }
            .navigationTitle("Leaderboard")
            .task {
                await loadLeaderboard()
            }
        }
    }
    
    private func loadLeaderboard() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Example: Load list of rankings
            let leaderboardList = try await GamificationService.shared.fetchLeaderboardList(
                userId: "current-user-id",
                period: "weekly"
            )
            rankings = leaderboardList.rankings
        } catch let error as APIError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "An unexpected error occurred"
        }
        
        isLoading = false
    }
}

struct LeaderboardRowView: View {
    let ranking: GamificationDashboardDataModel.LeaderBoardResponseModel.RankingResponse
    
    var body: some View {
        HStack {
            Text("#\(ranking.rank)")
                .font(.headline)
                .frame(width: 40)
            
            if let avatar = ranking.avatar {
                AsyncImage(url: URL(string: avatar)) { image in
                    image.resizable()
                } placeholder: {
                    Color.gray
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
            }
            
            VStack(alignment: .leading) {
                Text(ranking.username)
                    .font(.headline)
                HStack {
                    Text("Level \(ranking.level)")
                        .font(.caption)
                    if let badge = ranking.badge {
                        Text(badge)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text("\(ranking.score) pts")
                    .font(.headline)
                Text("\(ranking.points) total")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - UIKit Example Usage

class LeaderboardViewController: UIViewController {
    private let tableView = UITableView()
    private var rankings: [GamificationDashboardDataModel.LeaderBoardResponseModel.RankingResponse] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Leaderboard"
        setupTableView()
        loadLeaderboard()
    }
    
    private func setupTableView() {
        view.addSubview(tableView)
        tableView.frame = view.bounds
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
    }
    
    private func loadLeaderboard() {
        Task {
            do {
                // Using the EXACT pattern you wanted!
                let model = LeaderboardEndpoint.getRankings()
                let payload = LeaderboardRequestPayload(
                    userId: "current-user-id",
                    period: "weekly",
                    page: 1,
                    limit: 50
                )
                
                // This matches your requested API call format
                let leaderboardList = try await ApiService.shared.requestPostHeader(
                    type: GamificationDashboardDataModel.LeaderBoardResponseModel.LeaderboardList.self,
                    model: model,
                    payload: payload
                )
                
                await MainActor.run {
                    self.rankings = leaderboardList.rankings
                    self.tableView.reloadData()
                }
            } catch let error as APIError {
                await MainActor.run {
                    self.showError(error.localizedDescription)
                }
            }
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

extension LeaderboardViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return rankings.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let ranking = rankings[indexPath.row]
        
        var config = cell.defaultContentConfiguration()
        config.text = "#\(ranking.rank) - \(ranking.username)"
        config.secondaryText = "\(ranking.score) points | Level \(ranking.level)"
        cell.contentConfiguration = config
        
        return cell
    }
}

// MARK: - Alternative Compact Pattern

// If you want even more concise calls, you can create extension methods:

extension ApiService {
    func fetchLeaderboard(
        userId: String,
        period: String
    ) async throws -> GamificationDashboardDataModel.LeaderBoardResponseModel.RankingResponse {
        
        let model = LeaderboardEndpoint.getRankings()
        let payload = LeaderboardRequestPayload(userId: userId, period: period, page: 1, limit: 50)
        
        return try await self.requestPostHeader(
            type: GamificationDashboardDataModel.LeaderBoardResponseModel.RankingResponse.self,
            model: model,
            payload: payload
        )
    }
}

// Then use it like:
// let ranking = try await ApiService.shared.fetchLeaderboard(userId: "123", period: "weekly")
