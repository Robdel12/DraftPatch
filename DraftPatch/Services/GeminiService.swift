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
  let apiKey: String? = KeychainHelper.shared.load(for: "gemini_api_key") ?? ""

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
    // TODO: Add to settings? Probably (x2)
    let allowedModels: Set<String> = [
      "gemini-1.5-pro",
      "gemini-1.5-flash",
      "gemini-2.0-pro",
      "gemini-2.0-flash",
      "gemini-2.0-flash-lite",
    ]

    return decoded.models.compactMap { modelInfo in
      let rawName = modelInfo.name
      let modelName = rawName.hasPrefix("models/") ? String(rawName.dropFirst("models/".count)) : rawName

      return allowedModels.contains(modelName) ? modelName : nil
    }
  }

  // MARK: - Streaming Chat
  func streamChat(messages: [ChatMessagePayload], modelName: String) -> AsyncThrowingStream<String, Error> {
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
          //   "contents": [
          //     { "role": "user", "parts": [ {"text": "..."} ] },
          //     { "role": "model","parts": [ {"text": "..."} ] }
          //   ]
          // }
          struct RequestBody: Encodable {
            let contents: [Content]
          }
          struct Content: Encodable {
            let role: String?
            let parts: [Part]
          }
          struct Part: Encodable {
            let text: String
          }

          // Filter out messages with empty content
          let filteredMessages = messages.filter {
            !$0.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
          }

          let contents = filteredMessages.map { msg in
            Content(role: msg.role.rawValue, parts: [Part(text: msg.content)])
          }

          let requestBody = RequestBody(contents: contents)
          request.httpBody = try JSONEncoder().encode(requestBody)

          // Perform SSE streaming request
          let (byteStream, response) = try await URLSession.shared.bytes(for: request)
          guard let httpResponse = response as? HTTPURLResponse,
            (200..<300).contains(httpResponse.statusCode)
          else {
            var errorData = Data()
            for try await chunk in byteStream {
              errorData.append(chunk)
            }
            let errorString = String(data: errorData, encoding: .utf8) ?? "<no body>"
            print("streamChat error. Status: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
            print("Body: \(errorString)")
            throw URLError(.badServerResponse)
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
              if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                let candidates = json["candidates"] as? [[String: Any]],
                let firstCandidate = candidates.first,
                let content = firstCandidate["content"] as? [String: Any],
                let parts = content["parts"] as? [[String: Any]],
                let text = parts.first?["text"] as? String
              {
                continuation.yield(text)
              }
            } catch {
              // SSE can push partial lines or other event data. Usually safe to ignore.
              print("Non-JSON SSE line: \(line)")
            }
          }

          continuation.finish()

        } catch {
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
    systemPrompt: String?
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

    let combinedText =
      systemPrompt.flatMap { $0.isEmpty ? nil : $0 }
      .map { "\($0)\n\n\(message)" } ?? message

    struct RequestBody: Encodable {
      let contents: [Content]
    }
    struct Content: Encodable {
      let parts: [Part]
    }
    struct Part: Encodable {
      let text: String
    }

    let body = RequestBody(contents: [
      Content(parts: [Part(text: combinedText)])
    ])
    request.httpBody = try JSONEncoder().encode(body)

    let (data, response) = try await URLSession.shared.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse,
      (200..<300).contains(httpResponse.statusCode)
    else {
      // If non-2xx, attempt to read the error body for details
      let errorString = String(data: data, encoding: .utf8) ?? "<no body>"
      print("singleChatCompletion error. Status: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
      print("Body: \(errorString)")
      throw URLError(.badServerResponse)
    }

    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let candidates = json["candidates"] as? [[String: Any]],
      let firstCandidate = candidates.first,
      let content = firstCandidate["content"] as? [String: Any],
      let parts = content["parts"] as? [[String: Any]],
      let text = parts.first?["text"] as? String
    {
      return text
    }

    throw URLError(.cannotParseResponse)
  }
}
