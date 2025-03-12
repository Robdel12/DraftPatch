//
//  MockLLMService.swift
//  DraftPatch
//
//  Created by Robert DeLuca on 3/11/25.
//

import Foundation

class MockLLMManager: LLMManager {
  override func getService(for provider: ChatModel.LLMProvider) -> LLMService {
    return MockLLMService.shared
  }

  override func loadLLMs(_ settings: Settings?) async -> [ChatModel] {
    return try! await MockLLMService.shared.fetchAvailableModels().map {
      ChatModel(name: $0, provider: .ollama)
    }
  }
}

class MockLLMService: LLMService {
  static let shared = MockLLMService()

  var endpointURL: URL
  var apiKey: String?

  init(endpointURL: URL = URL(string: "http://example.com")!, apiKey: String? = nil) {
    self.endpointURL = endpointURL
    self.apiKey = apiKey
  }

  func fetchAvailableModels() async throws -> [String] {
    return ["MockModel1", "MockModel2", "MockModel3"]
  }

  func streamChat(
    messages: [ChatMessagePayload],
    modelName: String
  ) -> AsyncThrowingStream<String, Error> {
    AsyncThrowingStream { continuation in
      let tokens = ["Hello ", "world!"]
      for token in tokens {
        continuation.yield(token)
      }

      continuation.finish()
    }
  }

  func singleChatCompletion(
    message: String,
    modelName: String,
    systemPrompt: String? = nil
  ) async throws -> String {
    return "Mock single completion for message: \(message)"
  }

  func generateTitle(
    for message: String,
    modelName: String
  ) async throws -> String {
    // Return a mock title.
    return "Mock Title"
  }
}
