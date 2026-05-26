import SwiftUI

struct ContentView: View {
    @State private var selectedCommunity: String = "Home"
    @State private var communities: [String] = [
        "Home", "Popular", "All", "Random",
        "r/apple", "r/swift", "r/iOSProgramming", "r/programming"
    ]
    
    @StateObject private var translationService = TranslationService()
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    var body: some View {
        if horizontalSizeClass == .compact {
            VStack(spacing: 0) {
                translationToolbar
                
                WebViewContainer(url: redditURL(for: selectedCommunity), translationService: translationService)
                    .ignoresSafeArea()
            }
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
                                translationService.translationEnabled = false
                            } label: {
                                Label(community, systemImage: iconFor(community))
                                    .foregroundStyle(selectedCommunity == community ? Color.accentColor : Color.primary)
                            }
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    
                    Divider()
                    
                    translationToggle
                        .padding(16)
                }
                .frame(width: 280)
                .background(Color(.systemGray6))
                
                Divider()
                
                VStack(spacing: 0) {
                    if translationService.isTranslating {
                        translationProgress
                    }
                    
                    WebViewContainer(url: redditURL(for: selectedCommunity), translationService: translationService)
                        .ignoresSafeArea()
                }
            }
        }
    }
    
    private var translationToolbar: some View {
        HStack {
            Spacer()
            
            Button {
                translationService.translationEnabled.toggle()
            } label: {
                if translationService.isTranslating {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: translationService.translationEnabled ? "character.bubble.fill" : "character.bubble")
                        .foregroundStyle(translationService.translationEnabled ? Color.accentColor : Color.primary)
                }
            }
            .padding(.trailing, 16)
        }
        .frame(height: 44)
        .background(Color(.systemBackground))
    }
    
    private var translationToggle: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("翻译功能")
                .font(.subheadline)
                .fontWeight(.medium)
            
            Toggle("显示中文翻译", isOn: $translationService.translationEnabled)
                .toggleStyle(.switch)
                .disabled(translationService.isTranslating)
            
            if translationService.isTranslating {
                HStack {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("正在翻译...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Text("使用 iOS 系统翻译将英文段落翻译为简体中文")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    private var translationProgress: some View {
        HStack {
            ProgressView()
            Text("正在翻译页面内容...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
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