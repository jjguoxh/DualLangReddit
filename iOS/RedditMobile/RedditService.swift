import Foundation

struct Subreddit: Codable, Identifiable {
    let id: String
    let name: String
    let displayName: String
    let url: String
    let subscriberCount: Int?
    let description: String?
    
    init(id: String, name: String, displayName: String, url: String, subscriberCount: Int? = nil, description: String? = nil) {
        self.id = id
        self.name = name
        self.displayName = displayName
        self.url = url
        self.subscriberCount = subscriberCount
        self.description = description
    }
}

class RedditService {
    static let shared = RedditService()
    
    private let baseURL = "https://www.reddit.com"
    private let session: URLSession
    private let userDefaultsKey = "customSubreddits"
    
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        session = URLSession(configuration: config)
    }
    
    func getPopularSubreddits(limit: Int = 25, completion: @escaping ([Subreddit]?, Error?) -> Void) {
        let urlString = "\(baseURL)/subreddits/popular.json?limit=\(limit)"
        guard let url = URL(string: urlString) else {
            completion(nil, NSError(domain: "RedditService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]))
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("iOS:RedditMobile:v1.0 (by /u/RedditMobileApp)", forHTTPHeaderField: "User-Agent")
        
        session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(nil, error)
                return
            }
            
            guard let data = data else {
                completion(nil, NSError(domain: "RedditService", code: -2, userInfo: [NSLocalizedDescriptionKey: "No data received"]))
                return
            }
            
            do {
                let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                let dataDict = json?["data"] as? [String: Any]
                let children = dataDict?["children"] as? [[String: Any]]
                
                var subreddits: [Subreddit] = []
                
                for child in children ?? [] {
                    let subredditData = child["data"] as? [String: Any]
                    let id = subredditData?["id"] as? String ?? ""
                    let name = subredditData?["name"] as? String ?? ""
                    let displayName = subredditData?["display_name"] as? String ?? ""
                    let urlPath = subredditData?["url"] as? String ?? ""
                    let subscribers = subredditData?["subscribers"] as? Int
                    let description = subredditData?["public_description"] as? String
                    
                    let subreddit = Subreddit(
                        id: id,
                        name: name,
                        displayName: displayName,
                        url: urlPath,
                        subscriberCount: subscribers,
                        description: description
                    )
                    subreddits.append(subreddit)
                }
                
                completion(subreddits, nil)
            } catch {
                completion(nil, error)
            }
        }.resume()
    }
    
    func getDefaultSubreddits(limit: Int = 25, completion: @escaping ([Subreddit]?, Error?) -> Void) {
        let urlString = "\(baseURL)/subreddits/default.json?limit=\(limit)"
        guard let url = URL(string: urlString) else {
            completion(nil, NSError(domain: "RedditService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]))
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("iOS:RedditMobile:v1.0 (by /u/RedditMobileApp)", forHTTPHeaderField: "User-Agent")
        
        session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(nil, error)
                return
            }
            
            guard let data = data else {
                completion(nil, NSError(domain: "RedditService", code: -2, userInfo: [NSLocalizedDescriptionKey: "No data received"]))
                return
            }
            
            do {
                let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                let dataDict = json?["data"] as? [String: Any]
                let children = dataDict?["children"] as? [[String: Any]]
                
                var subreddits: [Subreddit] = []
                
                for child in children ?? [] {
                    let subredditData = child["data"] as? [String: Any]
                    let id = subredditData?["id"] as? String ?? ""
                    let name = subredditData?["name"] as? String ?? ""
                    let displayName = subredditData?["display_name"] as? String ?? ""
                    let urlPath = subredditData?["url"] as? String ?? ""
                    let subscribers = subredditData?["subscribers"] as? Int
                    let description = subredditData?["public_description"] as? String
                    
                    let subreddit = Subreddit(
                        id: id,
                        name: name,
                        displayName: displayName,
                        url: urlPath,
                        subscriberCount: subscribers,
                        description: description
                    )
                    subreddits.append(subreddit)
                }
                
                completion(subreddits, nil)
            } catch {
                completion(nil, error)
            }
        }.resume()
    }
    
    func saveCustomSubreddit(_ subreddit: Subreddit) {
        var customSubreddits = loadCustomSubreddits()
        
        if !customSubreddits.contains(where: { $0.name == subreddit.name }) {
            customSubreddits.append(subreddit)
            
            if let encoded = try? JSONEncoder().encode(customSubreddits) {
                UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
            }
        }
    }
    
    func loadCustomSubreddits() -> [Subreddit] {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let subreddits = try? JSONDecoder().decode([Subreddit].self, from: data) else {
            return []
        }
        return subreddits
    }
    
    func removeCustomSubreddit(_ subreddit: Subreddit) {
        var customSubreddits = loadCustomSubreddits()
        customSubreddits.removeAll { $0.name == subreddit.name }
        
        if let encoded = try? JSONEncoder().encode(customSubreddits) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
    }
    
    func searchSubreddits(query: String, limit: Int = 10, completion: @escaping ([Subreddit]?, Error?) -> Void) {
        let urlString = "\(baseURL)/subreddits/search.json?q=\(query)&limit=\(limit)"
        guard let url = URL(string: urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "") else {
            completion(nil, NSError(domain: "RedditService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]))
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("iOS:RedditMobile:v1.0 (by /u/RedditMobileApp)", forHTTPHeaderField: "User-Agent")
        
        session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(nil, error)
                return
            }
            
            guard let data = data else {
                completion(nil, NSError(domain: "RedditService", code: -2, userInfo: [NSLocalizedDescriptionKey: "No data received"]))
                return
            }
            
            do {
                let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                let dataDict = json?["data"] as? [String: Any]
                let children = dataDict?["children"] as? [[String: Any]]
                
                var subreddits: [Subreddit] = []
                
                for child in children ?? [] {
                    let subredditData = child["data"] as? [String: Any]
                    let id = subredditData?["id"] as? String ?? ""
                    let name = subredditData?["name"] as? String ?? ""
                    let displayName = subredditData?["display_name"] as? String ?? ""
                    let urlPath = subredditData?["url"] as? String ?? ""
                    let subscribers = subredditData?["subscribers"] as? Int
                    let description = subredditData?["public_description"] as? String
                    
                    let subreddit = Subreddit(
                        id: id,
                        name: name,
                        displayName: displayName,
                        url: urlPath,
                        subscriberCount: subscribers,
                        description: description
                    )
                    subreddits.append(subreddit)
                }
                
                completion(subreddits, nil)
            } catch {
                completion(nil, error)
            }
        }.resume()
    }
}