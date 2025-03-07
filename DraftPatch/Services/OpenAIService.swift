//
//  OpenAIService.swift
//  DraftPatch
//
//  Created by Robert DeLuca on 3/6/25.
//

import Foundation

struct OpenAIService: LLMService {
  @MainActor static let shared = OpenAIService()

  let endpointURL: URL = URL(string: "https://api.openai.com/v1")!
  let apiKey: String? = KeychainHelper.shared.load(for: "openai_api_key") ?? ""

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
    // TODO: Add to settings? Probably
    let modelsToKeep: Set<String> = ["o1", "o1-mini", "gpt-4o", "gpt-4o-mini", "o3-mini"]
    let filteredModels = decodedResponse.data
      .map { $0.id }
      .filter { modelsToKeep.contains($0) }

    return filteredModels
  }

  func streamChat(
    messages: [ChatMessagePayload],
    modelName: String
  ) -> AsyncThrowingStream<String, Error> {
    AsyncThrowingStream { continuation in
      Task {
        do {
          let url = endpointURL.appendingPathComponent("chat/completions")
          var request = URLRequest(url: url)
          request.httpMethod = "POST"
          request.setValue("Bearer \(apiKey ?? "")", forHTTPHeaderField: "Authorization")
          request.setValue("application/json", forHTTPHeaderField: "Content-Type")

          let requestBody =
            [
              "model": modelName,
              "messages": messages.map { ["role": $0.role.rawValue, "content": $0.content] },
              "stream": true,
            ] as [String: Any]

          request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

          let (stream, response) = try await URLSession.shared.bytes(for: request)
          guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
          }

          for try await line in stream.lines {
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
          continuation.finish(throwing: error)
        }
      }
    }
  }

  func singleChatCompletion(
    message: String,
    modelName: String,
    systemPrompt: String?
  ) async throws -> String {
    let url = endpointURL.appendingPathComponent("chat/completions")
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("Bearer \(apiKey ?? "")", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    let messages: [[String: Any]] = [
      ["role": "system", "content": systemPrompt ?? ""],
      ["role": "user", "content": message],
    ].filter { $0["content"] as? String != "" }

    let requestBody =
      [
        "model": modelName,
        "messages": messages,
      ] as [String: Any]

    request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

    let (data, response) = try await URLSession.shared.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
      throw URLError(.badServerResponse)
    }

    struct Response: Codable {
      struct Choice: Codable {
        struct Message: Codable {
          let content: String
        }
        let message: Message
      }
      let choices: [Choice]
    }

    let decodedResponse = try JSONDecoder().decode(Response.self, from: data)
    return decodedResponse.choices.first?.message.content ?? ""
  }
}
