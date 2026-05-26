import SwiftUI

struct ContentView: View {
    @State private var selectedCommunity: String = "Home"
    @State private var communities: [String] = [
        "Home", "Popular", "All", "Random",
        "r/apple", "r/swift", "r/iOSProgramming", "r/programming"
    ]
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    var body: some View {
        if horizontalSizeClass == .compact {
            WebViewContainer(url: redditURL(for: selectedCommunity))
                .ignoresSafeArea()
        } else {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Reddit")
                        .font(.headline)
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 8)
                    
                    List {
                        ForEach(communities, id: \.self) { community in
                            Button {
                                selectedCommunity = community
                            } label: {
                                Label(community, systemImage: iconFor(community))
                                    .foregroundStyle(selectedCommunity == community ? Color.accentColor : Color.primary)
                            }
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
                .frame(width: 280)
                .background(Color(.systemGray6))
                
                Divider()
                
                WebViewContainer(url: redditURL(for: selectedCommunity))
                    .ignoresSafeArea()
            }
        }
    }
    
    private func redditURL(for community: String) -> URL {
        if community == "Home" {
            return URL(string: "https://www.reddit.com/")!
        } else if community == "Popular" {
            return URL(string: "https://www.reddit.com/r/popular/")!
        } else if community == "All" {
            return URL(string: "https://www.reddit.com/r/all/")!
        } else if community == "Random" {
            return URL(string: "https://www.reddit.com/random/")!
        } else if community.hasPrefix("r/") {
            return URL(string: "https://www.reddit.com/\(community)/")!
        } else {
            return URL(string: "https://www.reddit.com/")!
        }
    }
    
    private func iconFor(_ community: String) -> String {
        if community == "Home" { return "house.fill" }
        else if community == "Popular" { return "flame.fill" }
        else if community == "All" { return "globe.americas.fill" }
        else if community == "Random" { return "shuffle" }
        else { return "bubble.left.and.bubble.right.fill" }
    }
}

#Preview {
    ContentView()
}