//
//  OllamaService.swift
//  DraftPatch
//
//  Created by Robert DeLuca on 3/2/25.
//

import Foundation

final class OllamaService {
  static let shared = OllamaService()
  private let baseURL = URL(string: "http://localhost:11434")!

  // List local models
  // GET /api/tags => { "models": [{ "name": "llama3.2", ... }, ...] }
  func fetchAvailableModels() async throws -> [String] {
    let url = baseURL.appendingPathComponent("api/tags")
    let (data, _) = try await URLSession.shared.data(from: url)

    guard
      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let models = json["models"] as? [[String: Any]]
    else {
      return []
    }
    return models.compactMap { $0["name"] as? String }
  }

  // Generate a title for the chat thread based on the user's first message
  func generateTitle(for message: String, modelName: String) async throws -> String {
    let url = baseURL.appendingPathComponent("api/generate")
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")

    let prompt = """
      Summarize the following message into a short title (5 words or less). \
      Do not include quotes or punctuation. Only output the final short title. \
      Do not quote it. The output will be used for a coversation title.

      \(message)
      """

    let payload: [String: Any] = [
      "model": modelName,
      "prompt": prompt,
      "stream": false,
    ]

    request.httpBody = try JSONSerialization.data(withJSONObject: payload)

    let (data, _) = try await URLSession.shared.data(for: request)
    guard
      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let rawTitle = json["response"] as? String
    else {
      throw NSError(
        domain: "OllamaService",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Invalid response"]
      )
    }

    var cleanedTitle = rawTitle.replacingOccurrences(
      of: "<think>[\\s\\S]*?</think>",
      with: "",
      options: .regularExpression
    )

    cleanedTitle =
      cleanedTitle
      .replacingOccurrences(of: "[\"'.,!?;:]", with: "", options: .regularExpression)
      .trimmingCharacters(in: .whitespacesAndNewlines)

    return cleanedTitle
  }

  // POST /api/chat => streaming
  func streamChat(messages: [[String: Any]], modelName: String) -> AsyncStream<String> {
    let url = baseURL.appendingPathComponent("api/chat")
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")

    let payload: [String: Any] = [
      "model": modelName,
      "messages": messages,
      "stream": true,
    ]

    do {
      request.httpBody = try JSONSerialization.data(withJSONObject: payload)
    } catch {
      return AsyncStream { $0.finish() }
    }

    return AsyncStream<String> { continuation in
      Task {
        do {
          let (stream, _) = try await URLSession.shared.bytes(for: request)

          for try await line in stream.lines {
            guard let data = line.data(using: .utf8),
              let chunk = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else {
              continue
            }

            // chunk might look like:
            // {
            //   "model": "...",
            //   "created_at": "...",
            //   "message": { "role": "assistant", "content": "partial" },
            //   "done": false
            // }
            if let messageObj = chunk["message"] as? [String: Any],
              let partialText = messageObj["content"] as? String,
              !partialText.isEmpty
            {
              continuation.yield(partialText)
            }

            if let done = chunk["done"] as? Bool, done {
              continuation.finish()
              return
            }
          }

          continuation.finish()
        } catch {
          print("Stream error: \(error)")
          continuation.finish()
        }
      }
    }
  }
}
