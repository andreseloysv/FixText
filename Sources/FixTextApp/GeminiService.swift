import Foundation

struct GeminiService {
    enum ServiceError: LocalizedError {
        case missingAPIKey
        case invalidResponse
        case httpError(status: Int, body: String)

        var errorDescription: String? {
            switch self {
            case .missingAPIKey:
                return "Add your Gemini API key inside the app before sending prompts."
            case .invalidResponse:
                return "Gemini returned an unexpected response."
            case .httpError(let status, let body):
                return "Gemini error \(status): \(body)"
            }
        }
    }

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func send(prompt: String, apiKey: String?) async throws -> String {
        guard let apiKey, !apiKey.isEmpty else {
            throw ServiceError.missingAPIKey
        }

        guard var components = URLComponents(
            string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent"
        ) else {
            throw ServiceError.invalidResponse
        }

        components.queryItems = [URLQueryItem(name: "key", value: apiKey)]

        guard let url = components.url else {
            throw ServiceError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = GeminiRequest(
            contents: [
                .init(parts: [.init(text: prompt)])
            ]
        )

        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ServiceError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let bodyText = String(data: data, encoding: .utf8) ?? "No body"
            throw ServiceError.httpError(status: httpResponse.statusCode, body: bodyText)
        }

        let decoded = try JSONDecoder().decode(GeminiResponse.self, from: data)
        guard let reply = decoded.firstText else {
            throw ServiceError.invalidResponse
        }

        return reply.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct GeminiRequest: Encodable {
    struct Content: Encodable {
        struct Part: Encodable {
            let text: String
        }

        let parts: [Part]
    }

    let contents: [Content]
}

private struct GeminiResponse: Decodable {
    struct Candidate: Decodable {
        struct Content: Decodable {
            struct Part: Decodable {
                let text: String?
            }

            let parts: [Part]?
        }

        let content: Content?
    }

    let candidates: [Candidate]?

    var firstText: String? {
        candidates?
            .compactMap { $0.content?.parts?.compactMap { $0.text }.joined(separator: "\n") }
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
