import Foundation
import Combine
import Translation

@available(iOS 18.0, *)
class TranslationService: ObservableObject {
    @Published var isTranslating: Bool = false
    @Published var translationEnabled: Bool = false
    
    func translateBatch(paragraphs: [String], completion: @escaping (([(String, String?)]) -> Void)) {
        guard translationEnabled else {
            completion(paragraphs.map { ($0, nil) })
            return
        }
        
        isTranslating = true
        
        Task { @MainActor in
            do {
                let sourceLanguage = Locale.Language(identifier: "en")
                let targetLanguage = Locale.Language(identifier: "zh-Hans")
                
                let session = try TranslationSession(installedSource: sourceLanguage, target: targetLanguage)
                
                var results: [(String, String?)] = []
                
                for paragraph in paragraphs {
                    if paragraph.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        results.append((paragraph, nil))
                        continue
                    }
                    
                    do {
                        let response = try await session.translate(paragraph)
                        results.append((paragraph, response.targetText))
                    } catch {
                        print("Failed to translate paragraph: \(error)")
                        results.append((paragraph, nil))
                    }
                }
                
                isTranslating = false
                completion(results)
            } catch {
                isTranslating = false
                print("Translation session initialization error: \(error)")
                print("Note: Translation languages may need to be downloaded first")
                completion(paragraphs.map { ($0, nil) })
            }
        }
    }
}