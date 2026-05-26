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
            isPageLoaded = true
            print("   isPageLoaded set to true")
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
        
        func translatePage(webView: WKWebView, service: TranslationService) {
            print("🚀 translatePage called")
            
            let extractJS = """
            (function() {
                var paragraphs = [];
                var elements = document.querySelectorAll('p, h1, h2, h3, h4, h5, h6, article p, div[data-click-id="body"] p, div[data-testid="post-container"] p');
                for (var i = 0; i < Math.min(elements.length, 30); i++) {
                    var el = elements[i];
                    var text = el.innerText.trim();
                    if (text.length > 15 && text.length < 1000 && !el.querySelector('img, video')) {
                        paragraphs.push(text);
                    }
                }
                return paragraphs;
            })();
            """
            
            print("   📝 Extracting paragraphs with JavaScript")
            webView.evaluateJavaScript(extractJS) { result, error in
                if let error = error {
                    print("   ❌ Paragraph extraction error: \(error)")
                    return
                }
                
                if let paragraphs = result as? [String], !paragraphs.isEmpty {
                    print("   ✅ Found \(paragraphs.count) paragraphs to translate")
                    print("   First 3 paragraphs: \(paragraphs.prefix(3))")
                    service.translateBatch(paragraphs: paragraphs) { translations in
                        print("   🎯 Translation completed, inserting results")
                        self.insertTranslations(webView: webView, translations: translations)
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
        
        private func insertTranslations(webView: WKWebView, translations: [(String, String?)]) {
            print("💉 insertTranslations called with \(translations.count) items")
            var jsCode = "(function() {"
            var insertedCount = 0
            
            for (index, (_, translated)) in translations.enumerated() {
                if let translation = translated, !translation.isEmpty {
                    print("   📄 Translation \(index): \(translation.prefix(50))...")
                    let escaped = translation
                        .replacingOccurrences(of: "'", with: "\\'")
                        .replacingOccurrences(of: "\n", with: "\\n")
                        .replacingOccurrences(of: "\"", with: "\\\"")
                        .replacingOccurrences(of: "<", with: "&lt;")
                        .replacingOccurrences(of: ">", with: "&gt;")
                    
                    jsCode += """
                    var elements = document.querySelectorAll('p, h1, h2, h3, h4, h5, h6, article p, div[data-click-id="body"] p, div[data-testid="post-container"] p');
                    if (elements[\(index)]) {
                        var div = document.createElement('div');
                        div.className = 'translated-text';
                        div.textContent = '翻译: \(escaped)';
                        elements[\(index)].parentNode.insertBefore(div, elements[\(index)].nextSibling);
                    }
                    """
                    insertedCount += 1
                }
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
    }
}