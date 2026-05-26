import Foundation
import Combine

class SubredditManager: ObservableObject {
    @Published var popularSubreddits: [Subreddit] = []
    @Published var defaultSubreddits: [Subreddit] = []
    @Published var customSubreddits: [Subreddit] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private let redditService = RedditService.shared
    
    init() {
        loadCustomSubreddits()
        loadPopularSubreddits()
    }
    
    func loadPopularSubreddits() {
        isLoading = true
        errorMessage = nil
        
        redditService.getPopularSubreddits(limit: 50) { subreddits, error in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    self.errorMessage = "Failed to load popular subreddits: \(error.localizedDescription)"
                    print("❌ Error loading popular subreddits: \(error)")
                } else if let subreddits = subreddits {
                    self.popularSubreddits = subreddits
                    print("✅ Loaded \(subreddits.count) popular subreddits")
                }
            }
        }
    }
    
    func loadDefaultSubreddits() {
        isLoading = true
        errorMessage = nil
        
        redditService.getDefaultSubreddits(limit: 50) { subreddits, error in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    self.errorMessage = "Failed to load default subreddits: \(error.localizedDescription)"
                    print("❌ Error loading default subreddits: \(error)")
                } else if let subreddits = subreddits {
                    self.defaultSubreddits = subreddits
                    print("✅ Loaded \(subreddits.count) default subreddits")
                }
            }
        }
    }
    
    func loadCustomSubreddits() {
        customSubreddits = redditService.loadCustomSubreddits()
        print("✅ Loaded \(customSubreddits.count) custom subreddits from storage")
    }
    
    func addCustomSubreddit(name: String) {
        let displayName = name.hasPrefix("r/") ? name : "r/\(name)"
        let urlPath = "/\(displayName)/"
        
        let subreddit = Subreddit(
            id: "custom_\(name)",
            name: displayName,
            displayName: displayName,
            url: urlPath
        )
        
        redditService.saveCustomSubreddit(subreddit)
        customSubreddits.append(subreddit)
        print("✅ Added custom subreddit: \(displayName)")
    }
    
    func removeCustomSubreddit(_ subreddit: Subreddit) {
        redditService.removeCustomSubreddit(subreddit)
        customSubreddits.removeAll { $0.id == subreddit.id }
        print("🗑️ Removed custom subreddit: \(subreddit.displayName)")
    }
    
    func searchSubreddits(query: String, completion: @escaping ([Subreddit]?) -> Void) {
        redditService.searchSubreddits(query: query, limit: 20) { subreddits, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Search error: \(error)")
                    completion(nil)
                } else {
                    completion(subreddits)
                }
            }
        }
    }
    
    func getAllSubreddits() -> [Subreddit] {
        var allSubreddits: [Subreddit] = []
        
        let homeSubreddit = Subreddit(id: "home", name: "Home", displayName: "Home", url: "/")
        let popularSubreddit = Subreddit(id: "popular", name: "Popular", displayName: "Popular", url: "/r/popular/")
        let allSubreddit = Subreddit(id: "all", name: "All", displayName: "All", url: "/r/all/")
        let randomSubreddit = Subreddit(id: "random", name: "Random", displayName: "Random", url: "/random/")
        
        allSubreddits.append(contentsOf: [homeSubreddit, popularSubreddit, allSubreddit, randomSubreddit])
        
        if !customSubreddits.isEmpty {
            allSubreddits.append(contentsOf: customSubreddits)
        }
        
        if !popularSubreddits.isEmpty {
            allSubreddits.append(contentsOf: popularSubreddits.prefix(10))
        }
        
        return allSubreddits
    }
}