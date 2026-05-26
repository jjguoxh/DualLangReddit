import Foundation

struct RedditUser: Codable {
    let name: String
    let linkKarma: Int
    let commentKarma: Int
    let totalKarma: Int
    
    init(name: String, linkKarma: Int, commentKarma: Int) {
        self.name = name
        self.linkKarma = linkKarma
        self.commentKarma = commentKarma
        self.totalKarma = linkKarma + commentKarma
    }
    
    enum CodingKeys: String, CodingKey {
        case name
        case linkKarma = "link_karma"
        case commentKarma = "comment_karma"
        case totalKarma = "total_karma"
    }
}

class KarmaService {
    static let shared = KarmaService()
    
    private let baseURL = "https://www.reddit.com"
    private let session: URLSession
    private var karmaCache: [String: RedditUser] = [:]
    
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        session = URLSession(configuration: config)
    }
    
    func getUserInfo(username: String, completion: @escaping (RedditUser?, Error?) -> Void) {
        if let cachedUser = karmaCache[username] {
            completion(cachedUser, nil)
            return
        }
        
        let urlString = "\(baseURL)/user/\(username)/about.json"
        guard let url = URL(string: urlString) else {
            completion(nil, NSError(domain: "KarmaService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]))
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
                completion(nil, NSError(domain: "KarmaService", code: -2, userInfo: [NSLocalizedDescriptionKey: "No data received"]))
                return
            }
            
            do {
                let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                let dataDict = json?["data"] as? [String: Any]
                
                let name = dataDict?["name"] as? String ?? username
                let linkKarma = dataDict?["link_karma"] as? Int ?? 0
                let commentKarma = dataDict?["comment_karma"] as? Int ?? 0
                
                let user = RedditUser(name: name, linkKarma: linkKarma, commentKarma: commentKarma)
                
                self.karmaCache[username] = user
                
                completion(user, nil)
            } catch {
                completion(nil, error)
            }
        }.resume()
    }
    
    func getMultipleUsersInfo(usernames: [String], completion: @escaping ([String: RedditUser]?, Error?) -> Void) {
        var users: [String: RedditUser] = [:]
        var errors: [Error] = []
        var completed = 0
        
        for username in usernames {
            getUserInfo(username: username) { user, error in
                completed += 1
                
                if let user = user {
                    users[username] = user
                } else if let error = error {
                    errors.append(error)
                }
                
                if completed == usernames.count {
                    if users.isEmpty && !errors.isEmpty {
                        completion(nil, errors.first)
                    } else {
                        completion(users, nil)
                    }
                }
            }
        }
    }
    
    func formatKarma(_ karma: Int) -> String {
        if karma >= 1_000_000 {
            return String(format: "%.1fM", Double(karma) / 1_000_000)
        } else if karma >= 1_000 {
            return String(format: "%.1fK", Double(karma) / 1_000)
        } else {
            return String(karma)
        }
    }
    
    func getKarmaColor(_ karma: Int) -> String {
        if karma >= 100_000 {
            return "#FFD700"
        } else if karma >= 10_000 {
            return "#FFA500"
        } else if karma >= 1_000 {
            return "#4CAF50"
        } else if karma >= 100 {
            return "#2196F3"
        } else {
            return "#9E9E9E"
        }
    }
}