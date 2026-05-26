import SwiftUI

struct ContentView: View {
    @StateObject private var subredditManager = SubredditManager()
    @StateObject private var translationService = TranslationService()
    @State private var selectedSubreddit: Subreddit?
    @State private var shouldTranslate = false
    @State private var showAddSubredditSheet = false
    @State private var searchText = ""
    @State private var searchResults: [Subreddit] = []
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    var body: some View {
        if horizontalSizeClass == .compact {
            VStack(spacing: 0) {
                translationToolbar
                
                WebViewContainer(url: redditURL(for: selectedSubreddit), translationService: translationService, shouldTranslate: $shouldTranslate)
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
                        Section(header: Text("快捷访问")) {
                            ForEach([Subreddit(id: "home", name: "Home", displayName: "Home", url: "/"),
                                     Subreddit(id: "popular", name: "Popular", displayName: "Popular", url: "/r/popular/"),
                                     Subreddit(id: "all", name: "All", displayName: "All", url: "/r/all/"),
                                     Subreddit(id: "random", name: "Random", displayName: "Random", url: "/random/")], id: \.id) { subreddit in
                                Button {
                                    selectedSubreddit = subreddit
                                } label: {
                                    Label(subreddit.displayName, systemImage: iconFor(subreddit))
                                        .foregroundStyle(selectedSubreddit?.id == subreddit.id ? Color.accentColor : Color.primary)
                                }
                                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            }
                        }
                        
                        if !subredditManager.customSubreddits.isEmpty {
                            Section(header: Text("我的社区")) {
                                ForEach(subredditManager.customSubreddits) { subreddit in
                                    Button {
                                        selectedSubreddit = subreddit
                                    } label: {
                                        HStack {
                                            Label(subreddit.displayName, systemImage: "star.fill")
                                                .foregroundStyle(selectedSubreddit?.id == subreddit.id ? Color.accentColor : Color.primary)
                                            
                                            Spacer()
                                            
                                            Button {
                                                subredditManager.removeCustomSubreddit(subreddit)
                                            } label: {
                                                Image(systemName: "trash")
                                                    .foregroundStyle(.red)
                                                    .font(.caption)
                                            }
                                        }
                                    }
                                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                                }
                            }
                        }
                        
                        if subredditManager.isLoading {
                            Section(header: Text("热门社区")) {
                                HStack {
                                    ProgressView()
                                    Text("正在加载...")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        } else if !subredditManager.popularSubreddits.isEmpty {
                            Section(header: Text("热门社区")) {
                                ForEach(subredditManager.popularSubreddits.prefix(15)) { subreddit in
                                    Button {
                                        selectedSubreddit = subreddit
                                    } label: {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Label(subreddit.displayName, systemImage: "bubble.left.and.bubble.right.fill")
                                                .foregroundStyle(selectedSubreddit?.id == subreddit.id ? Color.accentColor : Color.primary)
                                            
                                            if let subscribers = subreddit.subscriberCount {
                                                Text("\(formatNumber(subscribers)) 订阅者")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                    }
                                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                                }
                            }
                        }
                        
                        if let errorMessage = subredditManager.errorMessage {
                            Section {
                                Text(errorMessage)
                                    .foregroundStyle(.red)
                                    .font(.caption)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    
                    Divider()
                    
                    VStack(spacing: 12) {
                        translationButton
                        
                        addSubredditButton
                    }
                    .padding(16)
                }
                .frame(width: 280)
                .background(Color(.systemGray6))
                
                Divider()
                
                VStack(spacing: 0) {
                    if translationService.isTranslating {
                        translationProgress
                    }
                    
                    WebViewContainer(url: redditURL(for: selectedSubreddit), translationService: translationService, shouldTranslate: $shouldTranslate)
                        .ignoresSafeArea()
                }
            }
        }
    }
    
    private var translationToolbar: some View {
        HStack {
            Spacer()
            
            Button {
                shouldTranslate = true
            } label: {
                if translationService.isTranslating {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "character.bubble")
                        .foregroundStyle(Color.primary)
                }
            }
            .padding(.trailing, 16)
        }
        .frame(height: 44)
        .background(Color(.systemBackground))
    }
    
    private var translationButton: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("翻译功能")
                .font(.subheadline)
                .fontWeight(.medium)
            
            Button {
                shouldTranslate = true
            } label: {
                HStack {
                    if translationService.isTranslating {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("正在翻译...")
                            .font(.subheadline)
                    } else {
                        Image(systemName: "character.bubble")
                        Text("翻译页面内容")
                            .font(.subheadline)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.accentColor)
                .foregroundStyle(.white)
                .cornerRadius(8)
            }
            .disabled(translationService.isTranslating)
            
            Text("点击按钮翻译当前页面的英文内容为简体中文")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    private var addSubredditButton: some View {
        Button {
            showAddSubredditSheet = true
        } label: {
            HStack {
                Image(systemName: "plus.circle.fill")
                Text("添加自定义社区")
                    .font(.subheadline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color(.systemGray5))
            .foregroundStyle(.primary)
            .cornerRadius(8)
        }
        .sheet(isPresented: $showAddSubredditSheet) {
            AddSubredditSheet(subredditManager: subredditManager, selectedSubreddit: $selectedSubreddit)
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
    
    private func redditURL(for subreddit: Subreddit?) -> URL {
        let path = subreddit?.url ?? "/"
        return URL(string: "https://www.reddit.com\(path)")!
    }
    
    private func iconFor(_ subreddit: Subreddit) -> String {
        if subreddit.id == "home" { return "house.fill" }
        else if subreddit.id == "popular" { return "flame.fill" }
        else if subreddit.id == "all" { return "globe.americas.fill" }
        else if subreddit.id == "random" { return "shuffle" }
        else { return "bubble.left.and.bubble.right.fill" }
    }
    
    private func formatNumber(_ number: Int) -> String {
        if number >= 1_000_000 {
            return String(format: "%.1fM", Double(number) / 1_000_000)
        } else if number >= 1_000 {
            return String(format: "%.1fK", Double(number) / 1_000)
        } else {
            return String(number)
        }
    }
}

struct AddSubredditSheet: View {
    @ObservedObject var subredditManager: SubredditManager
    @Binding var selectedSubreddit: Subreddit?
    @Environment(\.dismiss) var dismiss
    
    @State private var searchText = ""
    @State private var searchResults: [Subreddit] = []
    @State private var isSearching = false
    @State private var manualInput = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                TextField("搜索社区（例如：swift, programming）", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)
                    .onSubmit {
                        searchSubreddits()
                    }
                
                Button("搜索") {
                    searchSubreddits()
                }
                .disabled(searchText.isEmpty || isSearching)
                
                if isSearching {
                    ProgressView()
                        .padding()
                }
                
                if !searchResults.isEmpty {
                    List {
                        ForEach(searchResults) { subreddit in
                            Button {
                                subredditManager.addCustomSubreddit(name: subreddit.displayName)
                                selectedSubreddit = subreddit
                                dismiss()
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(subreddit.displayName)
                                        .font(.headline)
                                    
                                    if let subscribers = subreddit.subscriberCount {
                                        Text("\(formatNumber(subscribers)) 订阅者")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    
                                    if let description = subreddit.description, !description.isEmpty {
                                        Text(description)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("手动添加")
                        .font(.headline)
                    
                    TextField("输入社区名称（例如：r/swift）", text: $manualInput)
                        .textFieldStyle(.roundedBorder)
                        .padding(.horizontal)
                    
                    Button("添加") {
                        let name = manualInput.hasPrefix("r/") ? manualInput : "r/\(manualInput)"
                        subredditManager.addCustomSubreddit(name: name)
                        
                        let newSubreddit = Subreddit(
                            id: "custom_\(name)",
                            name: name,
                            displayName: name,
                            url: "/\(name)/"
                        )
                        selectedSubreddit = newSubreddit
                        dismiss()
                    }
                    .disabled(manualInput.isEmpty)
                }
                .padding()
                
                Spacer()
            }
            .navigationTitle("添加社区")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func searchSubreddits() {
        isSearching = true
        
        subredditManager.searchSubreddits(query: searchText) { results in
            isSearching = false
            searchResults = results ?? []
        }
    }
    
    private func formatNumber(_ number: Int) -> String {
        if number >= 1_000_000 {
            return String(format: "%.1fM", Double(number) / 1_000_000)
        } else if number >= 1_000 {
            return String(format: "%.1fK", Double(number) / 1_000)
        } else {
            return String(number)
        }
    }
}

#Preview {
    ContentView()
}