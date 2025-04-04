//
//  OpenAIService.swift
//  DraftPatch
//
//  Created by Robert DeLuca on 3/6/25.
//

import Foundation

final class OpenAIService: LLMService {
  static let shared = OpenAIService()

  let endpointURL: URL = URL(string: "https://api.openai.com/v1")!
  var apiKey: String? {
    KeychainHelper.shared.load(for: "openai_api_key")
  }

  var isCancelled: Bool = false

  func fetchAvailableModels() async throws -> [String] {
    let url = endpointURL.appendingPathComponent("models")
    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.setValue("Bearer \(apiKey ?? "")", forHTTPHeaderField: "Authorization")

    let (data, response) = try await URLSession.shared.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
      throw URLError(.badServerResponse)
    }

    struct ModelsResponse: Codable {
      let data: [Model]
    }

    struct Model: Codable {
      let id: String
    }

    let decodedResponse = try JSONDecoder().decode(ModelsResponse.self, from: data)
    let filteredModels = decodedResponse.data
      .map { $0.id }

    return filteredModels
  }

  func streamChat(
    messages: [ChatMessagePayload],
    modelName: String,
    model: ChatModel
  ) -> AsyncThrowingStream<String, Error> {
    isCancelled = false

    return AsyncThrowingStream { continuation in
      Task {
        do {
          let url = endpointURL.appendingPathComponent("chat/completions")
          var request = URLRequest(url: url)
          request.httpMethod = "POST"
          request.setValue("Bearer \(apiKey ?? "")", forHTTPHeaderField: "Authorization")
          request.setValue("application/json", forHTTPHeaderField: "Content-Type")

          var preparedMessages = messages.map { ["role": $0.role.rawValue, "content": $0.content] }

          if let systemPrompt = model.defaultSystemPrompt, !systemPrompt.isEmpty {
            preparedMessages.insert(["role": "system", "content": systemPrompt], at: 0)
          }

          var requestBody: [String: Any] = [
            "model": modelName,
            "messages": preparedMessages,
            "stream": true,
          ]

          if let temp = model.defaultTemperature {
            requestBody["temperature"] = temp
          }
          if let topP = model.defaultTopP {
            requestBody["top_p"] = topP
          }
          if let maxTokens = model.defaultMaxTokens {
            requestBody["max_tokens"] = maxTokens
          }

          request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

          let (stream, response) = try await URLSession.shared.bytes(for: request)
          guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            var errorData = Data()
            for try await chunk in stream {
              errorData.append(chunk)
            }
            let errorString = String(data: errorData, encoding: .utf8) ?? "<no body>"
            print("streamChat error. Status: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
            print("Body: \(errorString)")
            throw URLError(
              .badServerResponse,
              userInfo: [
                NSLocalizedDescriptionKey:
                  "HTTP \((response as? HTTPURLResponse)?.statusCode ?? -1): \(errorString)"
              ])
          }

          for try await line in stream.lines {
            if self.isCancelled {
              continuation.finish()
              return
            }

            guard line.hasPrefix("data: ") else {
              continue
            }

            let jsonString = String(line.dropFirst(6))
            if jsonString.trimmingCharacters(in: .whitespacesAndNewlines) == "[DONE]" {
              print("Stream finished.")
              break
            }

            guard let jsonData = jsonString.data(using: .utf8),
              let jsonObject = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let choices = jsonObject["choices"] as? [[String: Any]]
            else {
              print("Failed to parse JSON: \(jsonString)")
              continue
            }

            // Extract content if available
            if let delta = choices.first?["delta"] as? [String: Any],
              let content = delta["content"] as? String, !content.isEmpty
            {
              continuation.yield(content)
            }

            // Handle finish reason
            if let finishReason = choices.first?["finish_reason"] as? String, finishReason == "stop" {
              break
            }
          }

          continuation.finish()
        } catch {
          print("OpenAI streamChat error: \(error)")
          continuation.finish(throwing: error)
        }
      }
    }
  }

  func cancelStreamChat() {
    isCancelled = true
  }

  func singleChatCompletion(
    message: String,
    modelName: String,
    model: ChatModel
  ) async throws -> String {
    let url = endpointURL.appendingPathComponent("chat/completions")
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("Bearer \(apiKey ?? "")", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    var messages: [[String: Any]] = []
    if let systemPrompt = model.defaultSystemPrompt, !systemPrompt.isEmpty {
      messages.append(["role": "system", "content": systemPrompt])
    }
    messages.append(["role": "user", "content": message])

    var requestBody: [String: Any] = [
      "model": modelName,
      "messages": messages,
    ]

    if let temp = model.defaultTemperature {
      requestBody["temperature"] = temp
    }
    if let topP = model.defaultTopP {
      requestBody["top_p"] = topP
    }
    if let maxTokens = model.defaultMaxTokens {
      requestBody["max_tokens"] = maxTokens
    }

    request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

    let (data, response) = try await URLSession.shared.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
      let errorString = String(data: data, encoding: .utf8) ?? "<no body>"
      print("singleChatCompletion error. Status: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
      print("Body: \(errorString)")
      throw URLError(
        .badServerResponse,
        userInfo: [
          NSLocalizedDescriptionKey:
            "HTTP \((response as? HTTPURLResponse)?.statusCode ?? -1): \(errorString)"
        ])
    }

    struct Response: Codable {
      struct Choice: Codable {
        struct Message: Codable {
          let content: String?  // Content can be nil sometimes
        }
        let message: Message
      }
      let choices: [Choice]
    }

    let decodedResponse = try JSONDecoder().decode(Response.self, from: data)
    return decodedResponse.choices.first?.message.content ?? ""
  }
}
