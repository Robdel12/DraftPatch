//
//  OllamaService.swift
//  DraftPatch
//
//  Created by Robert DeLuca on 3/2/25.
//

import Foundation

final class OllamaService: LLMService {
  static let shared = OllamaService()

  var endpointURL = URL(string: "http://localhost:11434")!
  var apiKey: String? = nil
  var isCancelled = false

  func fetchAvailableModels() async throws -> [String] {
    let url = endpointURL.appendingPathComponent("api/tags")
    let (data, _) = try await URLSession.shared.data(from: url)

    guard
      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let models = json["models"] as? [[String: Any]]
    else {
      throw NSError(
        domain: "OllamaService",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Invalid response"]
      )
    }

    return models.compactMap { $0["name"] as? String }
  }

  func singleChatCompletion(
    message: String,
    modelName: String,
    systemPrompt: String? = nil
  ) async throws -> String {
    let url = endpointURL.appendingPathComponent("api/chat")
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")

    var messagesPayload: [[String: Any]] = []
    if let systemPrompt {
      messagesPayload.append(["role": "system", "content": systemPrompt])
    }
    messagesPayload.append(["role": "user", "content": message])

    let payload: [String: Any] = [
      "model": modelName,
      "messages": messagesPayload,
      "stream": false,
    ]

    request.httpBody = try JSONSerialization.data(withJSONObject: payload)

    let (data, _) = try await URLSession.shared.data(for: request)

    guard
      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let messageObj = json["message"] as? [String: Any],
      let content = messageObj["content"] as? String
    else {
      throw NSError(
        domain: "OllamaService",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Invalid response"]
      )
    }

    return content.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  func streamChat(
    messages: [ChatMessagePayload],
    modelName: String
  ) -> AsyncThrowingStream<String, Error> {
    isCancelled = false

    return AsyncThrowingStream { continuation in
      Task {
        do {
          let url = endpointURL.appendingPathComponent("api/chat")
          var request = URLRequest(url: url)
          request.httpMethod = "POST"
          request.addValue("application/json", forHTTPHeaderField: "Content-Type")

          let messagesPayload = messages.map { message in
            [
              "role": message.role.rawValue,
              "content": message.content,
            ]
          }

          let payload: [String: Any] = [
            "model": modelName,
            "messages": messagesPayload,
            "stream": true,
          ]

          request.httpBody = try JSONSerialization.data(withJSONObject: payload)

          let (stream, _) = try await URLSession.shared.bytes(for: request)

          for try await line in stream.lines {
            if self.isCancelled {
              continuation.finish()
              return
            }

            guard let data = line.data(using: .utf8), !data.isEmpty else {
              continue
            }

            if let chunk = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let messageObj = chunk["message"] as? [String: Any],
              let partialText = messageObj["content"] as? String,
              !partialText.isEmpty
            {
              continuation.yield(partialText)

              if let done = chunk["done"] as? Bool, done {
                continuation.finish()
                return
              }
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

  func pullModel(modelName: String) -> AsyncThrowingStream<[String: Any], Error> {
    AsyncThrowingStream { continuation in
      Task {
        do {
          let url = endpointURL.appendingPathComponent("api/pull")
          var request = URLRequest(url: url)
          request.httpMethod = "POST"
          request.addValue("application/json", forHTTPHeaderField: "Content-Type")

          let payload: [String: Any] = [
            "model": modelName,
            "stream": true,
          ]

          request.httpBody = try JSONSerialization.data(withJSONObject: payload)

          let (stream, _) = try await URLSession.shared.bytes(for: request)

          for try await line in stream.lines {
            guard let data = line.data(using: .utf8), !data.isEmpty else { continue }

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
              continuation.yield(json)
            }
          }

          continuation.finish()
        } catch {
          continuation.finish(throwing: error)
        }
      }
    }
  }

  func deleteModel(modelName: String) async throws {
    let url = endpointURL.appendingPathComponent("api/delete")
    var request = URLRequest(url: url)
    request.httpMethod = "DELETE"
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")

    let payload: [String: Any] = ["model": modelName]
    request.httpBody = try JSONSerialization.data(withJSONObject: payload)

    let (_, response) = try await URLSession.shared.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse else {
      throw NSError(
        domain: "OllamaService",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Invalid response"]
      )
    }

    switch httpResponse.statusCode {
    case 200:
      return  // Success
    case 404:
      throw NSError(
        domain: "OllamaService",
        code: 404,
        userInfo: [NSLocalizedDescriptionKey: "Model not found"]
      )
    default:
      throw NSError(
        domain: "OllamaService",
        code: httpResponse.statusCode,
        userInfo: [NSLocalizedDescriptionKey: "Failed to delete model"]
      )
    }
  }
}
