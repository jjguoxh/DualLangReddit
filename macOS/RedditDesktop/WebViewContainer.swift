import SwiftUI
import WebKit

struct WebViewContainer: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        config.defaultWebpagePreferences = preferences

        let websiteDataStore = WKWebsiteDataStore.default()
        config.websiteDataStore = websiteDataStore

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")

        let request = URLRequest(url: url)
        webView.load(request)

        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            let js = """
            var style = document.createElement('style');
            style.innerHTML = '::-webkit-scrollbar { display: none; } html { overflow-y: scroll; scrollbar-width: none; }';
            document.head.appendChild(style);
            """
            webView.evaluateJavaScript(js)
        }
    }
}
