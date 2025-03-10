//
//  Settings.swift
//  DraftPatch
//
//  Created by Robert DeLuca on 3/7/25.
//

import Foundation
import SwiftData

@Model
class Settings {
  @Attribute(.unique) var id: UUID?

  var defaultModel: ChatModel? = nil
  var lastAppDraftedWith: DraftApp? = nil

  var ollamaConfig: OllamaConfig?
  var openAIConfig: OpenAIConfig?
  var geminiConfig: GeminiConfig?
  var anthropicConfig: AnthropicConfig?

  init(
    id: UUID? = nil,
    defaultModel: ChatModel? = nil,
    lastAppDraftedWith: DraftApp? = nil,
    ollamaConfig: OllamaConfig? = nil,
    openAIConfig: OpenAIConfig? = nil,
    geminiConfig: GeminiConfig? = nil,
    anthropicConfig: AnthropicConfig? = nil
  ) {
    self.id = id
    self.defaultModel = defaultModel
    self.lastAppDraftedWith = lastAppDraftedWith
    self.ollamaConfig = ollamaConfig
    self.openAIConfig = openAIConfig
    self.geminiConfig = geminiConfig
    self.anthropicConfig = anthropicConfig
  }
}

@Model
class OllamaConfig: LLMConfig {
  var temperature: Double
  var maxTokens: Int
  var enabled: Bool
  var localModelPath: String?
  var endpointURL: URL = URL(string: "http://localhost:11434")!

  init(
    temperature: Double = 0.7,
    maxTokens: Int = 2000,
    enabled: Bool = false,
    localModelPath: String? = nil,
    endpointURL: URL = URL(string: "http://localhost:11434")!
  ) {
    self.temperature = temperature
    self.maxTokens = maxTokens
    self.enabled = enabled
    self.localModelPath = localModelPath
    self.endpointURL = endpointURL
  }
}

@Model
class OpenAIConfig: LLMConfig {
  var temperature: Double
  var maxTokens: Int
  var enabled: Bool
  var apiKeyIdentifier: String?

  init(
    temperature: Double = 0.7,
    maxTokens: Int = 2000,
    enabled: Bool = false,
    apiKeyIdentifier: String? = nil
  ) {
    self.temperature = temperature
    self.maxTokens = maxTokens
    self.enabled = enabled
    self.apiKeyIdentifier = apiKeyIdentifier
  }
}

@Model
class GeminiConfig: LLMConfig {
  var temperature: Double
  var maxTokens: Int
  var enabled: Bool
  var apiKeyIdentifier: String?

  init(
    temperature: Double = 0.7,
    maxTokens: Int = 2000,
    enabled: Bool = false,
    apiKeyIdentifier: String? = nil
  ) {
    self.temperature = temperature
    self.maxTokens = maxTokens
    self.enabled = enabled
    self.apiKeyIdentifier = apiKeyIdentifier
  }
}

@Model
class AnthropicConfig: LLMConfig {
  var temperature: Double
  var maxTokens: Int
  var enabled: Bool
  var apiKeyIdentifier: String?

  init(
    temperature: Double = 0.7,
    maxTokens: Int = 2000,
    enabled: Bool = false,
    apiKeyIdentifier: String? = nil
  ) {
    self.temperature = temperature
    self.maxTokens = maxTokens
    self.enabled = enabled
    self.apiKeyIdentifier = apiKeyIdentifier
  }
}
