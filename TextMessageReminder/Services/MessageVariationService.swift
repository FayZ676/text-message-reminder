import Foundation

struct VariationRequest: Sendable {
    let baseMessage: String
    let contactName: String
    let title: String
}

enum MessageVariationError: Error {
    case missingAPIKey
    case requestFailed(String)
}

enum MessageVariationService {

    private static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    private static let model = "claude-haiku-4-5"

    private static let systemPrompt = """
        You rewrite short personal text messages so that a recurring message doesn't send the \
        exact same words every time.

        Rewrite the user's message with different wording while keeping the same intent, warmth, \
        and level of formality. Keep it roughly the same length. It is going out as an SMS, so \
        use plain text only — no markdown, no formatting. Only use emoji if the original had \
        them. Do not invent specifics (plans, times, events) that aren't in the original.

        Reply with the rewritten message and nothing else. No preamble, no quotation marks, no \
        alternatives, no commentary.
        """

    static func variation(for request: VariationRequest) async throws -> String {
        if ProcessInfo.processInfo.arguments.contains("-uitesting") {
            return "Varied: \(request.baseMessage)"
        }

        guard let apiKey = KeychainStore.apiKey() else { throw MessageVariationError.missingAPIKey }

        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        urlRequest.setValue("application/json", forHTTPHeaderField: "content-type")
        urlRequest.timeoutInterval = 20

        let body = RequestBody(
            model: model,
            maxTokens: 300,
            temperature: 1.0,
            system: systemPrompt,
            messages: [.init(role: "user", content: userPrompt(for: request))]
        )

        guard let encoded = try? JSONEncoder().encode(body) else {
            throw MessageVariationError.requestFailed("Couldn't build the request.")
        }
        urlRequest.httpBody = encoded

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: urlRequest)
        } catch {
            throw MessageVariationError.requestFailed(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw MessageVariationError.requestFailed("The response wasn't HTTP.")
        }

        guard (200..<300).contains(http.statusCode) else {
            throw MessageVariationError.requestFailed(
                "HTTP \(http.statusCode). \(apiErrorMessage(from: data) ?? "No details returned.")"
            )
        }

        guard let decoded = try? JSONDecoder().decode(ResponseBody.self, from: data) else {
            throw MessageVariationError.requestFailed("Couldn't read the API's response.")
        }

        guard let text = decoded.content.first(where: { $0.type == "text" })?.text else {
            throw MessageVariationError.requestFailed("The API returned no text.")
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw MessageVariationError.requestFailed("The API returned an empty message.")
        }

        return trimmed
    }

    private static func apiErrorMessage(from data: Data) -> String? {
        guard let decoded = try? JSONDecoder().decode(ErrorBody.self, from: data) else { return nil }
        return decoded.error.message
    }

    private static func userPrompt(for request: VariationRequest) -> String {
        var lines = ["Message to rewrite:", request.baseMessage]

        let name = request.contactName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty {
            lines.append("")
            lines.append("It is being sent to: \(name)")
        }

        let title = request.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !title.isEmpty {
            lines.append("The sender labelled this message: \(title)")
        }

        return lines.joined(separator: "\n")
    }

    private struct RequestBody: Encodable {
        let model: String
        let maxTokens: Int
        let temperature: Double
        let system: String
        let messages: [Message]

        struct Message: Encodable {
            let role: String
            let content: String
        }

        enum CodingKeys: String, CodingKey {
            case model
            case maxTokens = "max_tokens"
            case temperature
            case system
            case messages
        }
    }

    private struct ResponseBody: Decodable {
        let content: [Block]

        struct Block: Decodable {
            let type: String
            let text: String?
        }
    }

    private struct ErrorBody: Decodable {
        let error: Detail

        struct Detail: Decodable {
            let message: String
        }
    }
}
