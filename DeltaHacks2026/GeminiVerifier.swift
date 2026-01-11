
import Foundation
import UIKit

class GeminiVerifier {
    // Retrieve API Key from Secrets.plist
    private var apiKey: String {
        guard let filePath = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: filePath),
              let value = plist.object(forKey: "GEMINI_API_KEY") as? String else {
            fatalError("GEMINI_API_KEY not found in Secrets.plist. Please copy Secrets-Example.plist to Secrets.plist and add your key.")
        }
        return value
    }
    private let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent"
    
    enum VerificationError: Error {
        case invalidURL
        case imageEncodingFailed
        case networkError(Error)
        case invalidResponse
        case apiError(String)
    }
    
    func verifyTask(title: String, image: UIImage) async throws -> Bool {
        guard let url = URL(string: "\(endpoint)?key=\(apiKey)") else {
            throw VerificationError.invalidURL
        }
        
        // Resize image to reduce payload size (max 1024px)
        let resizedImage = resizeImage(image: image, targetSize: CGSize(width: 1024, height: 1024))
        
        guard let imageData = resizedImage.jpegData(compressionQuality: 0.8) else {
            throw VerificationError.imageEncodingFailed
        }
        
        let base64Image = imageData.base64EncodedString()
        
        // Construct Prompt
        let prompt = """
        I will provide an image and a task description.
        Task: "\(title)"
        
        Analyze the image. Does it visually confirm that this specific task has been completed?
        Be strict. If the image is irrelevant, blurry, or doesn't show the result, say NO.
        
        Respond with ONLY one word: "YES" or "NO".
        """
        
        // JSON Body
        let body: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": prompt],
                        [
                            "inline_data": [
                                "mime_type": "image/jpeg",
                                "data": base64Image
                            ]
                        ]
                    ]
                ]
            ]
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            // Try to parse detailed error message
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorObj = json["error"] as? [String: Any],
               let message = errorObj["message"] as? String {
                print("Gemini API Error: \(message)")
                throw VerificationError.apiError(message)
            }
            throw VerificationError.invalidResponse
        }
        
        // Parse Response
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let candidates = json["candidates"] as? [[String: Any]],
           let content = candidates.first?["content"] as? [String: Any],
           let parts = content["parts"] as? [[String: Any]],
           let text = parts.first?["text"] as? String {
            
            let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            print("Gemini Verification Result: \(cleanText)")
            return cleanText.contains("YES")
        }
        
        throw VerificationError.invalidResponse
    }
    
    // Helper to resize image
    private func resizeImage(image: UIImage, targetSize: CGSize) -> UIImage {
        let size = image.size
        let widthRatio  = targetSize.width  / size.width
        let heightRatio = targetSize.height / size.height
        let scaleFactor = min(widthRatio, heightRatio)
        let scaledSize  = CGSize(width: size.width * scaleFactor, height: size.height * scaleFactor)
        
        let renderer = UIGraphicsImageRenderer(size: scaledSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: scaledSize))
        }
    }
}

extension GeminiVerifier.VerificationError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid API URL."
        case .imageEncodingFailed: return "Could not encode image."
        case .networkError(let error): return "Network error: \(error.localizedDescription)"
        case .invalidResponse: return "Invalid response from AI server."
        case .apiError(let message): return "AI Error: \(message)"
        }
    }
}
