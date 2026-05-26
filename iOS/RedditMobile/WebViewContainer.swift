import SwiftUI
import WebKit

struct WebViewContainer: UIViewRepresentable {
    let url: URL
    @ObservedObject var translationService: TranslationService
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        config.defaultWebpagePreferences = preferences
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.delegate = context.coordinator
        webView.backgroundColor = .white
        
        context.coordinator.webView = webView
        
        let request = URLRequest(url: url)
        webView.load(request)
        
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        if translationService.translationEnabled && !translationService.isTranslating {
            if !context.coordinator.hasTranslated {
                context.coordinator.translatePage(webView: uiView, service: translationService)
            }
        } else if !translationService.translationEnabled && context.coordinator.hasTranslated {
            context.coordinator.removeTranslations(webView: uiView)
        }
        
        if context.coordinator.currentURL != url.absoluteString {
            context.coordinator.currentURL = url.absoluteString
            context.coordinator.hasTranslated = false
            context.coordinator.removeTranslations(webView: uiView)
            let request = URLRequest(url: url)
            uiView.load(request)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, UIScrollViewDelegate {
        var hasTranslated = false
        var currentURL: String = ""
        weak var webView: WKWebView?
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            let js = """
            var style = document.createElement('style');
            style.innerHTML = '::-webkit-scrollbar { display: none; } html { overflow-y: scroll; scrollbar-width: none; }';
            document.head.appendChild(style);
            """
            webView.evaluateJavaScript(js)
            
            injectTranslationStyles(webView: webView)
            
            if let service = (webView.superview?.superview as? UIView)?.findTranslationService() {
                if service.translationEnabled && !hasTranslated {
                    translatePage(webView: webView, service: service)
                }
            }
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("WebView failed with error: \(error.localizedDescription)")
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            print("WebView failed provisional navigation: \(error.localizedDescription)")
        }
        
        func scrollViewWillBeginZooming(_ scrollView: UIScrollView, with view: UIView?) {
            scrollView.pinchGestureRecognizer?.isEnabled = false
        }
        
        private func injectTranslationStyles(webView: WKWebView) {
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
            guard !hasTranslated else { return }
            hasTranslated = true
            
            let extractJS = """
            (function() {
                var paragraphs = [];
                var elements = document.querySelectorAll('p, h1, h2, h3, h4, h5, h6, article p, div[data-click-id="body"] p');
                for (var i = 0; i < Math.min(elements.length, 20); i++) {
                    var el = elements[i];
                    var text = el.innerText.trim();
                    if (text.length > 20 && text.length < 500 && !el.querySelector('img, video, a[href]')) {
                        paragraphs.push(text);
                    }
                }
                return paragraphs;
            })();
            """
            
            webView.evaluateJavaScript(extractJS) { result, error in
                if let error = error {
                    print("JavaScript extraction error: \(error)")
                    return
                }
                
                if let paragraphs = result as? [String], !paragraphs.isEmpty {
                    print("Extracted \(paragraphs.count) paragraphs for translation")
                    service.translateBatch(paragraphs: paragraphs) { translations in
                        self.insertTranslations(webView: webView, translations: translations)
                    }
                } else {
                    print("No paragraphs extracted from page")
                }
            }
        }
        
        private func insertTranslations(webView: WKWebView, translations: [(String, String?)]) {
            var jsCode = "(function() {"
            
            for (index, (_, translated)) in translations.enumerated() {
                if let translation = translated, !translation.isEmpty {
                    let escapedTranslation = translation
                        .replacingOccurrences(of: "'", with: "\\'")
                        .replacingOccurrences(of: "\n", with: "\\n")
                        .replacingOccurrences(of: "\"", with: "\\\"")
                        .replacingOccurrences(of: "<", with: "&lt;")
                        .replacingOccurrences(of: ">", with: "&gt;")
                    
                    jsCode += """
                    var elements = document.querySelectorAll('p, h1, h2, h3, h4, h5, h6, article p, div[data-click-id="body"] p');
                    if (elements[\(index)]) {
                        var translationDiv = document.createElement('div');
                        translationDiv.className = 'translated-text';
                        translationDiv.textContent = '翻译: \(escapedTranslation)';
                        elements[\(index)].parentNode.insertBefore(translationDiv, elements[\(index)].nextSibling);
                    }
                    """
                }
            }
            
            jsCode += "})();"
            
            webView.evaluateJavaScript(jsCode) { result, error in
                if let error = error {
                    print("Translation insertion error: \(error)")
                } else {
                    print("Successfully inserted translations")
                }
            }
        }
        
        func removeTranslations(webView: WKWebView) {
            hasTranslated = false
            let js = """
            (function() {
                var translations = document.querySelectorAll('.translated-text');
                translations.forEach(function(el) {
                    el.remove();
                });
            })();
            """
            webView.evaluateJavaScript(js)
        }
    }
}

extension UIView {
    func findTranslationService() -> TranslationService? {
        return nil
    }
}