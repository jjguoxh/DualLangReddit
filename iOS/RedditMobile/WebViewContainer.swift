import SwiftUI
import WebKit

struct WebViewContainer: UIViewRepresentable {
    let url: URL
    @ObservedObject var translationService: TranslationService
    @Binding var shouldTranslate: Bool
    
    func makeUIView(context: Context) -> WKWebView {
        print("🟢 WebViewContainer - makeUIView called for URL: \(url)")
        let config = WKWebViewConfiguration()
        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        config.defaultWebpagePreferences = preferences
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.delegate = context.coordinator
        webView.backgroundColor = .white
        
        context.coordinator.webView = webView
        context.coordinator.service = translationService
        
        let request = URLRequest(url: url)
        webView.load(request)
        
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        print("🟡 WebViewContainer - updateUIView called")
        print("   shouldTranslate: \(shouldTranslate)")
        print("   isPageLoaded: \(context.coordinator.isPageLoaded)")
        
        if context.coordinator.currentURL != url.absoluteString {
            print("   🔄 URL changed, reloading page")
            context.coordinator.currentURL = url.absoluteString
            context.coordinator.isPageLoaded = false
            context.coordinator.removeTranslations(webView: uiView)
            context.coordinator.removeKarmaBubbles(webView: uiView)
            let request = URLRequest(url: url)
            uiView.load(request)
        }
        
        if shouldTranslate && context.coordinator.isPageLoaded {
            print("   ✅ Triggering translation")
            context.coordinator.removeTranslations(webView: uiView)
            context.coordinator.translatePage(webView: uiView, service: translationService)
            DispatchQueue.main.async {
                shouldTranslate = false
                print("   🔙 shouldTranslate reset to false")
            }
        } else if shouldTranslate && !context.coordinator.isPageLoaded {
            print("   ⏳ Page not loaded yet, waiting...")
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, UIScrollViewDelegate {
        var isPageLoaded = false
        var currentURL: String = ""
        weak var webView: WKWebView?
        weak var service: TranslationService?
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("🔵 WebView - didFinish navigation")
            injectStyles(webView: webView)
            injectKarmaStyles(webView: webView)
            isPageLoaded = true
            print("   isPageLoaded set to true")
            
            extractAndDisplayKarma(webView: webView)
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("❌ WebView navigation failed: \(error.localizedDescription)")
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            print("❌ WebView provisional navigation failed: \(error.localizedDescription)")
        }
        
        func scrollViewWillBeginZooming(_ scrollView: UIScrollView, with view: UIView?) {
            scrollView.pinchGestureRecognizer?.isEnabled = false
        }
        
        private func injectStyles(webView: WKWebView) {
            let css = """
            .translated-text {
                background-color: #f0f7ff;
                padding: 8px 12px;
                border-radius: 8px;
                margin-top: 4px;
                margin-bottom: 12px;
                font-size: 0.95em;
                color: #333;
                border-left: 3px solid #007aff;
            }
            """
            
            let js = """
            var style = document.createElement('style');
            style.innerHTML = '\(css)';
            document.head.appendChild(style);
            """
            webView.evaluateJavaScript(js)
        }
        
        private func injectKarmaStyles(webView: WKWebView) {
            let css = """
            .karma-bubble {
                display: inline-block;
                padding: 2px 6px;
                border-radius: 12px;
                font-size: 11px;
                font-weight: 600;
                margin-left: 4px;
                color: white;
                text-shadow: 0 1px 1px rgba(0,0,0,0.2);
                box-shadow: 0 1px 3px rgba(0,0,0,0.1);
                vertical-align: middle;
            }
            """
            
            let js = """
            var style = document.createElement('style');
            style.innerHTML = '\(css)';
            document.head.appendChild(style);
            """
            webView.evaluateJavaScript(js)
        }
        
        func extractAndDisplayKarma(webView: WKWebView) {
            print("🔍 Extracting usernames for Karma display")
            
            let extractJS = """
            (function() {
                var usernames = [];
                var userElements = document.querySelectorAll('a[href^="/u/"], a[data-click-id="user"]');
                
                for (var i = 0; i < Math.min(userElements.length, 20); i++) {
                    var el = userElements[i];
                    var href = el.getAttribute('href');
                    var username = href.replace('/u/', '').replace('/', '').split('/')[0];
                    
                    if (username && username.length > 0 && !el.querySelector('.karma-bubble')) {
                        usernames.push(username);
                    }
                }
                
                return usernames;
            })();
            """
            
            webView.evaluateJavaScript(extractJS) { result, error in
                if let error = error {
                    print("   ❌ Username extraction error: \(error)")
                    return
                }
                
                if let usernames = result as? [String], !usernames.isEmpty {
                    print("   ✅ Found \(usernames.count) usernames: \(usernames)")
                    
                    KarmaService.shared.getMultipleUsersInfo(usernames: usernames) { users, error in
                        if let error = error {
                            print("   ❌ Karma fetch error: \(error)")
                            return
                        }
                        
                        if let users = users, !users.isEmpty {
                            print("   ✅ Got Karma for \(users.count) users")
                            self.insertKarmaBubbles(webView: webView, users: users)
                        }
                    }
                } else {
                    print("   ⚠️ No usernames found on page")
                }
            }
        }
        
        func translatePage(webView: WKWebView, service: TranslationService) {
            print("🚀 translatePage called")
            
            let extractJS = """
            (function() {
                var paragraphs = [];
                var indices = [];
                var elements = document.querySelectorAll('p, h1, h2, h3, h4, h5, h6, article p, div[data-click-id="body"] p, div[data-testid="post-container"] p');
                
                for (var i = 0; i < Math.min(elements.length, 30); i++) {
                    var el = elements[i];
                    var text = el.innerText.trim();
                    if (text.length > 15 && text.length < 1000 && !el.querySelector('img, video')) {
                        paragraphs.push(text);
                        indices.push(i);
                    }
                }
                
                return { paragraphs: paragraphs, indices: indices };
            })();
            """
            
            print("   📝 Extracting paragraphs with JavaScript")
            webView.evaluateJavaScript(extractJS) { result, error in
                if let error = error {
                    print("   ❌ Paragraph extraction error: \(error)")
                    return
                }
                
                if let resultDict = result as? [String: Any],
                   let paragraphs = resultDict["paragraphs"] as? [String],
                   let indices = resultDict["indices"] as? [Int],
                   !paragraphs.isEmpty {
                    
                    print("   ✅ Found \(paragraphs.count) paragraphs to translate")
                    print("   First 3 paragraphs: \(paragraphs.prefix(3))")
                    print("   Indices: \(indices)")
                    
                    service.translateBatch(paragraphs: paragraphs) { translations in
                        print("   🎯 Translation completed, inserting results")
                        self.insertTranslations(webView: webView, translations: translations, indices: indices)
                    }
                } else {
                    print("   ⚠️ No suitable paragraphs found on page")
                    if let result = result {
                        print("   Result type: \(type(of: result))")
                        print("   Result: \(result)")
                    }
                }
            }
        }
        
        private func insertTranslations(webView: WKWebView, translations: [(String, String?)], indices: [Int]) {
            print("💉 insertTranslations called with \(translations.count) items")
            print("   Indices to insert: \(indices)")
            
            var jsCode = "(function() {"
            var insertedCount = 0
            
            for (i, (_, translated)) in translations.enumerated() {
                guard let translation = translated, !translation.isEmpty else {
                    continue
                }
                
                guard i < indices.count else {
                    continue
                }
                
                let elementIndex = indices[i]
                
                print("   📄 Translation \(i): \(translation.prefix(50))... for element index \(elementIndex)")
                
                let escaped = translation
                    .replacingOccurrences(of: "'", with: "\\'")
                    .replacingOccurrences(of: "\n", with: "\\n")
                    .replacingOccurrences(of: "\"", with: "\\\"")
                    .replacingOccurrences(of: "<", with: "&lt;")
                    .replacingOccurrences(of: ">", with: "&gt;")
                
                jsCode += """
                var elements = document.querySelectorAll('p, h1, h2, h3, h4, h5, h6, article p, div[data-click-id="body"] p, div[data-testid="post-container"] p');
                if (elements[\(elementIndex)]) {
                    var div = document.createElement('div');
                    div.className = 'translated-text';
                    div.textContent = '翻译: \(escaped)';
                    elements[\(elementIndex)].parentNode.insertBefore(div, elements[\(elementIndex)].nextSibling);
                }
                """
                insertedCount += 1
            }
            
            jsCode += "})();"
            
            print("   🎨 Inserting \(insertedCount) translations into page")
            webView.evaluateJavaScript(jsCode) { _, error in
                if let error = error {
                    print("   ❌ Translation insertion error: \(error)")
                } else {
                    print("   ✅ Translations successfully inserted")
                }
            }
        }
        
        private func insertKarmaBubbles(webView: WKWebView, users: [String: RedditUser]) {
            print("💉 insertKarmaBubbles called")
            
            var jsCode = "(function() {"
            
            for (username, user) in users {
                let karma = user.totalKarma
                let formattedKarma = KarmaService.shared.formatKarma(karma)
                let karmaColor = KarmaService.shared.getKarmaColor(karma)
                
                print("   📊 \(username): \(formattedKarma) karma (color: \(karmaColor))")
                
                jsCode += """
                var userElements = document.querySelectorAll('a[href^="/u/\(username)"], a[href="/u/\(username)/"], a[data-click-id="user"]');
                for (var i = 0; i < userElements.length; i++) {
                    var el = userElements[i];
                    if (!el.querySelector('.karma-bubble')) {
                        var bubble = document.createElement('span');
                        bubble.className = 'karma-bubble';
                        bubble.style.backgroundColor = '\(karmaColor)';
                        bubble.textContent = '\(formattedKarma)';
                        el.appendChild(bubble);
                    }
                }
                """
            }
            
            jsCode += "})();"
            
            webView.evaluateJavaScript(jsCode) { _, error in
                if let error = error {
                    print("   ❌ Karma bubble insertion error: \(error)")
                } else {
                    print("   ✅ Karma bubbles successfully inserted")
                }
            }
        }
        
        func removeTranslations(webView: WKWebView) {
            print("🗑️ removeTranslations called")
            let js = """
            (function() {
                var translations = document.querySelectorAll('.translated-text');
                translations.forEach(function(el) { el.remove(); });
            })();
            """
            webView.evaluateJavaScript(js)
        }
        
        func removeKarmaBubbles(webView: WKWebView) {
            print("🗑️ removeKarmaBubbles called")
            let js = """
            (function() {
                var bubbles = document.querySelectorAll('.karma-bubble');
                bubbles.forEach(function(el) { el.remove(); });
            })();
            """
            webView.evaluateJavaScript(js)
        }
    }
}