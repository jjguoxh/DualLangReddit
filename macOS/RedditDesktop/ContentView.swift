import SwiftUI

struct ContentView: View {
    var body: some View {
        WebViewContainer(url: URL(string: "https://www.reddit.com/")!)
            .frame(minWidth: 800, minHeight: 600)
    }
}

#Preview {
    ContentView()
}
