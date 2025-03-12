//
//  LLMManager.swift
//  DraftPatch
//
//  Created by Robert DeLuca on 3/11/25.
//

class LLMManager {
  static let shared = LLMManager()

  func getService(for provider: ChatModel.LLMProvider) -> LLMService {
    switch provider {
    case .ollama:
      return OllamaService.shared
    case .openai:
      return OpenAIService.shared
    case .gemini:
      return GeminiService.shared
    case .anthropic:
      return ClaudeService.shared
    }
  }
}
