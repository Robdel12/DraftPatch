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
    model: ChatModel
  ) async throws -> String {
    let url = endpointURL.appendingPathComponent("api/chat")
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")

    var messagesPayload: [[String: Any]] = []
    if let systemPrompt = model.defaultSystemPrompt, !systemPrompt.isEmpty {
      messagesPayload.append(["role": "system", "content": systemPrompt])
    }
    messagesPayload.append(["role": "user", "content": message])

    var options: [String: Any] = [:]
    if let temp = model.defaultTemperature {
      options["temperature"] = temp
    }
    if let topP = model.defaultTopP {
      options["top_p"] = topP
    }
    if let maxTokens = model.defaultMaxTokens {
      options["num_predict"] = maxTokens
    }

    var payload: [String: Any] = [
      "model": modelName,
      "messages": messagesPayload,
      "stream": false,
    ]

    if !options.isEmpty {
      payload["options"] = options
    }

    request.httpBody = try JSONSerialization.data(withJSONObject: payload)

    let (data, response) = try await URLSession.shared.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse else {
      throw URLError(
        .badServerResponse, userInfo: [NSLocalizedDescriptionKey: "Response is not HTTPURLResponse"])
    }

    guard (200..<300).contains(httpResponse.statusCode) else {
      let errorString = String(data: data, encoding: .utf8) ?? "<no body>"
      print("Ollama singleChatCompletion error. Status: \(httpResponse.statusCode)")
      print("Body: \(errorString)")
      throw URLError(
        .badServerResponse,
        userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode): \(errorString)"])
    }

    guard
      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let messageObj = json["message"] as? [String: Any],
      let content = messageObj["content"] as? String
    else {
      print("Failed to parse Ollama response: \(String(data: data, encoding: .utf8) ?? "nil")")
      throw NSError(
        domain: "OllamaService",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Invalid response format"]
      )
    }

    return content.trimmingCharacters(in: .whitespacesAndNewlines)
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
          let url = endpointURL.appendingPathComponent("api/chat")
          var request = URLRequest(url: url)
          request.httpMethod = "POST"
          request.addValue("application/json", forHTTPHeaderField: "Content-Type")

          var messagesPayload = messages.map { message in
            [
              "role": message.role.rawValue,
              "content": message.content,
            ]
          }

          if let systemPrompt = model.defaultSystemPrompt, !systemPrompt.isEmpty {
            messagesPayload.insert(["role": "system", "content": systemPrompt], at: 0)
          }

          var options: [String: Any] = [:]
          if let temp = model.defaultTemperature {
            options["temperature"] = temp
          }
          if let topP = model.defaultTopP {
            options["top_p"] = topP
          }
          if let maxTokens = model.defaultMaxTokens {
            options["num_predict"] = maxTokens  // Ollama uses num_predict
          }

          var payload: [String: Any] = [
            "model": modelName,
            "messages": messagesPayload,
            "stream": true,
          ]

          if !options.isEmpty {
            payload["options"] = options
          }

          request.httpBody = try JSONSerialization.data(withJSONObject: payload)

          let (stream, response) = try await URLSession.shared.bytes(for: request)

          guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(
              .badServerResponse, userInfo: [NSLocalizedDescriptionKey: "Response is not HTTPURLResponse"])
          }

          guard (200..<300).contains(httpResponse.statusCode) else {
            var errorData = Data()
            for try await chunk in stream {
              errorData.append(chunk)
            }
            let errorString = String(data: errorData, encoding: .utf8) ?? "<no body>"
            print("Ollama streamChat error. Status: \(httpResponse.statusCode)")
            print("Body: \(errorString)")
            throw URLError(
              .badServerResponse,
              userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode): \(errorString)"])
          }

          for try await line in stream.lines {
            if self.isCancelled {
              continuation.finish()
              return
            }

            guard let data = line.data(using: .utf8), !data.isEmpty else {
              continue
            }

            // Ollama stream response format:
            // {"model":"...","created_at":"...","message":{"role":"assistant","content":"..." },"done":false}
            // ...
            // {"model":"...","created_at":"...","done":true,"total_duration":...,"load_duration":..., ... }
            do {
              if let chunk = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let messageObj = chunk["message"] as? [String: Any],
                  let partialText = messageObj["content"] as? String,
                  !partialText.isEmpty
                {
                  continuation.yield(partialText)
                }

                // Check for the 'done' field signaling the end of the stream *for this request*
                if let done = chunk["done"] as? Bool, done {
                  continuation.finish()
                  return
                }
              }
            } catch {
              print("Failed to parse Ollama stream chunk: \(line)")
              // Decide whether to continue or fail based on parsing errors
              // continuation.finish(throwing: error) // Option: fail on parse error
            }
          }
          // If the loop finishes without 'done: true', it might indicate an incomplete stream or issue.
          // Finishing here ensures the stream terminates, but might miss the final confirmation.
          continuation.finish()
        } catch {
          print("Ollama streamChat error: \(error)")
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
            "name": modelName,  // Use 'name' for pull API
            "stream": true,
          ]

          request.httpBody = try JSONSerialization.data(withJSONObject: payload)

          let (stream, response) = try await URLSession.shared.bytes(for: request)

          guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(
              .badServerResponse, userInfo: [NSLocalizedDescriptionKey: "Response is not HTTPURLResponse"])
          }

          guard (200..<300).contains(httpResponse.statusCode) else {
            var errorData = Data()
            for try await chunk in stream {
              errorData.append(chunk)
            }
            let errorString = String(data: errorData, encoding: .utf8) ?? "<no body>"
            print("Ollama pullModel error. Status: \(httpResponse.statusCode)")
            print("Body: \(errorString)")
            throw URLError(
              .badServerResponse,
              userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode): \(errorString)"])
          }

          for try await line in stream.lines {
            guard let data = line.data(using: .utf8), !data.isEmpty else { continue }

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
              continuation.yield(json)
              // Check for final status message if needed, e.g., json["status"] == "success"
              if let status = json["status"] as? String, status.contains("success") {
                // break or finish based on whether more status updates are expected
              }
            }
          }

          continuation.finish()
        } catch {
          print("Ollama pullModel error: \(error)")
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

    let payload: [String: Any] = ["name": modelName]  // Use 'name' for delete API
    request.httpBody = try JSONSerialization.data(withJSONObject: payload)

    let (data, response) = try await URLSession.shared.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse else {
      throw NSError(
        domain: "OllamaService",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Invalid response type"]
      )
    }

    switch httpResponse.statusCode {
    case 200:
      return  // Success
    case 404:
      let errorString = String(data: data, encoding: .utf8) ?? "Model not found"
      throw NSError(
        domain: "OllamaService",
        code: 404,
        userInfo: [NSLocalizedDescriptionKey: errorString]
      )
    default:
      let errorString = String(data: data, encoding: .utf8) ?? "Failed to delete model"
      throw NSError(
        domain: "OllamaService",
        code: httpResponse.statusCode,
        userInfo: [NSLocalizedDescriptionKey: errorString]
      )
    }
  }
}
