//
//  GeminiService.swift
//  DraftPatch
//
//  Created by Robert DeLuca on 3/8/25.
//

import Foundation

final class GeminiService: LLMService {
  static let shared = GeminiService()

  let endpointURL = URL(string: "https://generativelanguage.googleapis.com/v1beta/models")!
  var apiKey: String? {
    KeychainHelper.shared.load(for: "gemini_api_key")
  }

  var isCancelled: Bool = false

  // MARK: - Fetching Available Models
  func fetchAvailableModels() async throws -> [String] {
    guard let apiKey = apiKey, !apiKey.isEmpty else {
      throw URLError(.badServerResponse)
    }

    // GET /v1beta/models?key=<apiKey>
    var components = URLComponents(url: endpointURL, resolvingAgainstBaseURL: false)
    components?.queryItems = [URLQueryItem(name: "key", value: apiKey)]
    guard let finalURL = components?.url else {
      throw URLError(.badURL)
    }

    var request = URLRequest(url: finalURL)
    request.httpMethod = "GET"

    let (data, response) = try await URLSession.shared.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode)
    else {
      throw URLError(.badServerResponse)
    }

    // The response is like { "models": [ { "name": "models/gemini-1.5-flash" }, ... ] }
    struct ModelsResponse: Decodable {
      let models: [ModelInfo]
    }
    struct ModelInfo: Decodable {
      let name: String
    }

    let decoded = try JSONDecoder().decode(ModelsResponse.self, from: data)

    return decoded.models.map { modelInfo in
      let rawName = modelInfo.name
      return rawName.hasPrefix("models/") ? String(rawName.dropFirst("models/".count)) : rawName
    }
  }

  // MARK: - Streaming Chat
  func streamChat(
    messages: [ChatMessagePayload],
    modelName: String,
    model: ChatModel
  ) -> AsyncThrowingStream<String, Error> {
    isCancelled = false

    return AsyncThrowingStream { continuation in
      Task {
        do {
          guard let apiKey = apiKey, !apiKey.isEmpty else {
            throw URLError(.badServerResponse)
          }

          // POST /v1beta/models/<modelName>:streamGenerateContent?alt=sse&key=<apiKey>
          guard
            let url = URL(
              string: "\(endpointURL.absoluteString)/\(modelName):streamGenerateContent?alt=sse&key=\(apiKey)"
            )
          else {
            throw URLError(.badURL)
          }

          var request = URLRequest(url: url)
          request.httpMethod = "POST"
          request.setValue("application/json", forHTTPHeaderField: "Content-Type")

          // Body format:
          // {
          //   "contents": [ ... ],
          //   "systemInstruction": { "parts": [ {"text": "..."} ] }, // Optional
          //   "generationConfig": { // Optional
          //     "temperature": 0.9,
          //     "topP": 1.0,
          //     "maxOutputTokens": 2048
          //   }
          // }
          struct RequestBody: Encodable {
            let contents: [Content]
            let systemInstruction: SystemInstruction?
            let generationConfig: GenerationConfig?
          }
          struct Content: Encodable {
            let role: String?
            let parts: [Part]
          }
          struct Part: Encodable {
            let text: String
          }
          struct SystemInstruction: Encodable {
            let parts: [Part]
          }
          struct GenerationConfig: Encodable {
            let temperature: Double?
            let topP: Double?
            let maxOutputTokens: Int?  // Note: API uses maxOutputTokens
          }

          // Filter out messages with empty content
          let filteredMessages = messages.filter {
            !$0.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
          }

          // Gemini API wants `model` over `assistant` for the role.
          let contents = filteredMessages.map { msg in
            let role = msg.role.rawValue == "assistant" ? "model" : msg.role.rawValue
            return Content(role: role, parts: [Part(text: msg.content)])
          }

          // Prepare optional components
          var systemInstruction: SystemInstruction?
          if let sysPrompt = model.defaultSystemPrompt, !sysPrompt.isEmpty {
            systemInstruction = SystemInstruction(parts: [Part(text: sysPrompt)])
          }

          var generationConfig: GenerationConfig?
          if model.defaultTemperature != nil || model.defaultTopP != nil || model.defaultMaxTokens != nil {
            generationConfig = GenerationConfig(
              temperature: model.defaultTemperature,
              topP: model.defaultTopP,
              maxOutputTokens: model.defaultMaxTokens
            )
          }

          let requestBody = RequestBody(
            contents: contents,
            systemInstruction: systemInstruction,
            generationConfig: generationConfig
          )

          request.httpBody = try JSONEncoder().encode(requestBody)

          // Perform SSE streaming request
          let (byteStream, response) = try await URLSession.shared.bytes(for: request)
          guard let httpResponse = response as? HTTPURLResponse
          else {
            print("streamChat error: Response is not HTTPURLResponse")
            throw URLError(.badServerResponse)
          }

          guard (200..<300).contains(httpResponse.statusCode) else {
            var errorData = Data()
            for try await chunk in byteStream {
              errorData.append(chunk)
            }
            let errorString = String(data: errorData, encoding: .utf8) ?? "<no body>"
            print("streamChat error. Status: \(httpResponse.statusCode)")
            print("Body: \(errorString)")
            // Try to parse Gemini-specific error (Assuming ErrorDetails struct exists elsewhere or defined below)
            struct ErrorDetails: Decodable {  // Define if not global
              let code: Int?
              let message: String?
              let status: String?
            }
            if let jsonData = try? JSONDecoder().decode([String: ErrorDetails].self, from: errorData),
              let errorDetails = jsonData["error"],
              let errorMessage = errorDetails.message
            {
              let userInfo = [
                NSLocalizedDescriptionKey:
                  "Gemini API Error: \(errorMessage) (Code: \(errorDetails.code ?? -1))"
              ]
              continuation.finish(
                throwing: NSError(domain: "GeminiError", code: httpResponse.statusCode, userInfo: userInfo))
              return
            } else {
              continuation.finish(
                throwing: URLError(
                  .badServerResponse,
                  userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode): \(errorString)"]))
              return
            }
          }

          // Read lines from SSE: each line typically starts with "data: "
          for try await line in byteStream.lines {
            if self.isCancelled {
              continuation.finish()
              return
            }

            guard line.hasPrefix("data: ") else { continue }
            let jsonString = String(line.dropFirst("data: ".count))
            guard let data = jsonString.data(using: .utf8) else { continue }

            do {
              // Gemini Stream Response structure
              // { "candidates": [ { "content": { "parts": [ {"text": "..."} ], "role": "model" }, ... } ] }
              struct StreamResponse: Decodable {
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
              }

              let decoded = try JSONDecoder().decode(StreamResponse.self, from: data)

              if let text = decoded.candidates?.first?.content?.parts?.first?.text {
                continuation.yield(text)
              }
            } catch {
              // SSE can push partial lines or other event data. Usually safe to ignore.
              print("Non-JSON/unparsable SSE line: \(line)")
              print("Parsing error: \(error)")
            }
          }

          continuation.finish()

        } catch {
          print("Gemini streamChat error: \(error)")
          continuation.finish(throwing: error)
        }
      }
    }
  }

  func cancelStreamChat() {
    isCancelled = true
  }

  // MARK: - Single Chat Completion (Non-Streaming)
  func singleChatCompletion(
    message: String,
    modelName: String,
    model: ChatModel
  ) async throws -> String {
    guard let apiKey = apiKey, !apiKey.isEmpty else {
      throw URLError(.badServerResponse)
    }

    // POST /v1beta/models/<modelName>:generateContent?key=<apiKey>
    guard let url = URL(string: "\(endpointURL.absoluteString)/\(modelName):generateContent?key=\(apiKey)")
    else {
      throw URLError(.badURL)
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    struct RequestBody: Encodable {
      let contents: [Content]
      let systemInstruction: SystemInstruction?
      let generationConfig: GenerationConfig?  // Add generation config here too
    }
    struct Content: Encodable {
      let role: String?  // Role is optional for single-turn user message
      let parts: [Part]
    }
    struct Part: Encodable {
      let text: String
    }
    struct SystemInstruction: Encodable {
      let parts: [Part]
    }
    struct GenerationConfig: Encodable {
      let temperature: Double?
      let topP: Double?
      let maxOutputTokens: Int?
    }
    struct ErrorDetails: Decodable {  // Define ErrorDetails here as well if needed for single completion error handling
      let code: Int?
      let message: String?
      let status: String?
    }

    // Prepare optional components
    var systemInstruction: SystemInstruction?
    if let sysPrompt = model.defaultSystemPrompt, !sysPrompt.isEmpty {
      systemInstruction = SystemInstruction(parts: [Part(text: sysPrompt)])
    }

    var generationConfig: GenerationConfig?
    if model.defaultTemperature != nil || model.defaultTopP != nil || model.defaultMaxTokens != nil {
      generationConfig = GenerationConfig(
        temperature: model.defaultTemperature,
        topP: model.defaultTopP,
        maxOutputTokens: model.defaultMaxTokens ?? 2048  // Provide a default if needed for single completion
      )
    }

    // For single completion, just send the user message. System prompt is handled separately.
    let body = RequestBody(
      contents: [Content(role: "user", parts: [Part(text: message)])],
      systemInstruction: systemInstruction,
      generationConfig: generationConfig
    )
    request.httpBody = try JSONEncoder().encode(body)

    let (data, response) = try await URLSession.shared.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse else {
      throw URLError(
        .badServerResponse, userInfo: [NSLocalizedDescriptionKey: "Response was not HTTPURLResponse"])
    }

    guard (200..<300).contains(httpResponse.statusCode) else {
      let errorString = String(data: data, encoding: .utf8) ?? "<no body>"
      print("singleChatCompletion error. Status: \(httpResponse.statusCode)")
      print("Body: \(errorString)")
      // Try to parse Gemini-specific error
      if let jsonData = try? JSONDecoder().decode([String: ErrorDetails].self, from: data),
        let errorDetails = jsonData["error"],
        let errorMessage = errorDetails.message
      {
        let userInfo = [
          NSLocalizedDescriptionKey: "Gemini API Error: \(errorMessage) (Code: \(errorDetails.code ?? -1))"
        ]
        throw NSError(domain: "GeminiError", code: httpResponse.statusCode, userInfo: userInfo)
      } else {
        throw URLError(
          .badServerResponse,
          userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode): \(errorString)"])
      }
    }

    // Gemini Non-Stream Response structure
    // { "candidates": [ { "content": { "parts": [ {"text": "..."} ], "role": "model" }, ... } ] }
    struct SingleResponse: Decodable {
      struct Candidate: Decodable {
        struct Content: Decodable {
          struct Part: Decodable {
            let text: String
          }
          let parts: [Part]
        }
        let content: Content
      }
      let candidates: [Candidate]
    }

    do {
      let decoded = try JSONDecoder().decode(SingleResponse.self, from: data)
      if let text = decoded.candidates.first?.content.parts.first?.text {
        return text
      }
    } catch {
      print("Error decoding singleChatCompletion response: \(error)")
      print("Raw data: \(String(data: data, encoding: .utf8) ?? "nil")")
      throw URLError(.cannotParseResponse)
    }

    throw URLError(.cannotParseResponse)
  }
}
