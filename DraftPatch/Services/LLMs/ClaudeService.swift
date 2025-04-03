//
//  ClaudeService.swift
//  DraftPatch
//
//  Created by Robert DeLuca on 3/9/25.
//

import Foundation

final class ClaudeService: LLMService {
  static let shared = ClaudeService()

  let endpointURL = URL(string: "https://api.anthropic.com/v1")!
  var apiKey: String? {
    KeychainHelper.shared.load(for: "anthropic_api_key")
  }

  var streamChatTask: Task<Void, Never>?
  var isCancelled = false

  /// Fetches the list of available models from Anthropic
  func fetchAvailableModels() async throws -> [String] {
    let url = endpointURL.appendingPathComponent("models")
    var request = URLRequest(url: url)
    request.httpMethod = "GET"

    // Anthropic requires these headers
    request.setValue(apiKey ?? "", forHTTPHeaderField: "x-api-key")
    request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

    let (data, response) = try await URLSession.shared.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
      throw URLError(.badServerResponse)
    }

    struct ModelsResponse: Codable {
      let data: [AnthropicModel]
    }

    struct AnthropicModel: Codable {
      let id: String
    }

    let decodedResponse = try JSONDecoder().decode(ModelsResponse.self, from: data)
    // Marked as legacy models from Anthropic
    let modelsToExclude: Set<String> = ["claude-2.0", "claude-2.1", "claude-3-sonnet-20240229"]
    let modelIds = decodedResponse.data
      .map { $0.id }
      .filter { !modelsToExclude.contains($0) }

    return modelIds
  }

  func streamChat(
    messages: [ChatMessagePayload],
    modelName: String
  ) -> AsyncThrowingStream<String, Error> {
    isCancelled = false

    return AsyncThrowingStream { continuation in
      self.streamChatTask = Task {
        do {
          let url = endpointURL.appendingPathComponent("messages")

          var request = URLRequest(url: url)
          request.httpMethod = "POST"

          request.setValue(apiKey ?? "", forHTTPHeaderField: "x-api-key")
          request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
          request.setValue("token-efficient-tools-2025-02-19", forHTTPHeaderField: "anthropic-beta")
          request.setValue("application/json", forHTTPHeaderField: "Content-Type")

          let anthropicMessages = messages.map { msg -> [String: Any] in
            [
              "role": msg.role.rawValue,
              "content": msg.content,
            ]
          }

          var requestBody: [String: Any] = [
            "model": modelName,
            "messages": anthropicMessages,
            "max_tokens": 4096,
            "stream": true,
          ]

          if modelName.contains("claude-3-7") {
            requestBody["thinking"] =
              [
                "type": "enabled",
                "budget_tokens": 1024,
              ] as [String: Any]
          }

          let jsonData = try JSONSerialization.data(withJSONObject: requestBody, options: [.prettyPrinted])
          request.httpBody = jsonData

          let (bytesStream, response) = try await URLSession.shared.bytes(for: request)

          guard let httpResponse = response as? HTTPURLResponse else {
            print("[ClaudeService] Response was not an HTTPURLResponse.")
            throw URLError(.badServerResponse)
          }

          if httpResponse.statusCode != 200 {
            var errorData = Data()
            for try await byte in bytesStream {
              errorData.append(byte)
            }

            let errorBody = String(data: errorData, encoding: .utf8) ?? "<no error body>"
            print("[ClaudeService] Error body:\n\(errorBody)")

            if let jsonData = errorBody.data(using: .utf8) {
              do {
                if let jsonObject = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                  let errorDetails = jsonObject["error"] as? [String: Any],
                  let errorMessage = errorDetails["message"] as? String
                {
                  print("[ClaudeService] API Error:", errorMessage)
                  let anthropicError = NSError(
                    domain: "AnthropicError",
                    code: httpResponse.statusCode,
                    userInfo: [NSLocalizedDescriptionKey: errorMessage]
                  )

                  continuation.finish(throwing: anthropicError)
                  return
                }
              } catch {
                print("[ClaudeService] Failed to parse error response:", error.localizedDescription)
                continuation.finish(throwing: error)
                return
              }
            }

            let userInfo = [NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode): \(errorBody)"]
            continuation.finish(
              throwing: NSError(domain: "AnthropicError", code: httpResponse.statusCode, userInfo: userInfo))
          }

          var currentEvent: String?
          for try await line in bytesStream.lines {
            if self.isCancelled {
              continuation.finish()
              return
            }

            if line.hasPrefix("event: ") {
              currentEvent = String(line.dropFirst("event: ".count))
            } else if line.hasPrefix("data: ") {
              let jsonString = String(line.dropFirst("data: ".count))

              guard !jsonString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                continue
              }

              if currentEvent == "message_stop" {
                break
              }

              if let jsonData = jsonString.data(using: .utf8) {
                do {
                  if let jsonObject = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                    let eventType = jsonObject["type"] as? String
                  {
                    if eventType == "content_block_delta",
                      let deltaObj = jsonObject["delta"] as? [String: Any],
                      let textDelta = deltaObj["text"] as? String,
                      !textDelta.isEmpty
                    {
                      continuation.yield(textDelta)
                    }
                  }
                } catch {
                  print("[ClaudeService] JSON parsing error:", error.localizedDescription)
                }
              }
            }
          }

          continuation.finish()

        } catch {
          print("[ClaudeService] Caught error in streamChat():", error.localizedDescription)
          continuation.finish(throwing: error)
        }
      }
    }
  }

  func cancelStreamChat() {
    isCancelled = true
    streamChatTask?.cancel()
  }

  /// Creates a single (non-streaming) chat completion
  func singleChatCompletion(
    message: String,
    modelName: String,
    systemPrompt: String? = nil
  ) async throws -> String {
    let url = endpointURL.appendingPathComponent("messages")
    var request = URLRequest(url: url)
    request.httpMethod = "POST"

    request.setValue(apiKey ?? "", forHTTPHeaderField: "x-api-key")
    request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    let anthropicMessages: [[String: Any]] = [
      [
        "role": "user",
        "content": message,
      ]
    ]

    var requestBody: [String: Any] = [
      "model": modelName,
      "messages": anthropicMessages,
      "max_tokens": 256,
    ]

    if let systemPrompt = systemPrompt, !systemPrompt.isEmpty {
      requestBody["system"] = systemPrompt
    }

    request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

    let (data, response) = try await URLSession.shared.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
      throw URLError(.badServerResponse)
    }

    // Example success response shape:
    //
    // {
    //   "id": "msg_1234...",
    //   "model": "claude-3-7-...",
    //   "role": "assistant",
    //   "content": [ { "type": "text", "text": "Hello!" } ],
    //   "stop_reason": ...,
    //   "usage": ...
    // }
    //
    struct ClaudeResponse: Codable {
      struct ContentBlock: Codable {
        let type: String
        let text: String?
      }
      let content: [ContentBlock]
    }

    let decodedResponse = try JSONDecoder().decode(ClaudeResponse.self, from: data)

    let joinedText = decodedResponse.content
      .compactMap { block -> String? in
        guard block.type == "text", let text = block.text else { return nil }
        return text
      }
      .joined()

    return joinedText
  }
}
