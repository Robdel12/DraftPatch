//
//  LLMManager.swift
//  DraftPatch
//
//  Created by Robert DeLuca on 3/11/25.
//

class LLMManager {
  static let shared = LLMManager()

  func getService(for provider: LLMProvider) -> LLMService {
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

  func loadLLMs(_ settings: Settings?, existingModels: [ChatModel]) async -> [ChatModel] {
    var availableModels: [ChatModel] = []

    let providers: [(enabled: Bool, service: LLMService, provider: LLMProvider)] = [
      (settings?.ollamaConfig?.enabled ?? false, OllamaService.shared, .ollama),
      (settings?.openAIConfig?.enabled ?? false, OpenAIService.shared, .openai),
      (settings?.geminiConfig?.enabled ?? false, GeminiService.shared, .gemini),
      (settings?.anthropicConfig?.enabled ?? false, ClaudeService.shared, .anthropic),
    ]

    await withTaskGroup(of: [ChatModel].self) { group in
      for provider in providers where provider.enabled {
        group.addTask {
          do {
            let fetchedModelNames = try await provider.service.fetchAvailableModels()

            return fetchedModelNames.compactMap { modelName in
              if let existingModel = existingModels.first(where: {
                $0.name == modelName && $0.provider == provider.provider
              }) {
                return existingModel
              } else {
                return ChatModel(name: modelName, provider: provider.provider)
              }
            }
          } catch {
            print("Error loading \(provider.provider) models: \(error)")
            return []
          }
        }
      }

      for await models in group {
        availableModels.append(contentsOf: models)
      }
    }

    return Array(Set(availableModels))  // Remove duplicates if any
  }
}
