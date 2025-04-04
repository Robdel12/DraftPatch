//
//  ChatModel.swift
//  DraftPatch
//
//  Created by Robert DeLuca on 3/7/25.
//

import Foundation
import SwiftData

enum LLMProvider: String, Codable, CaseIterable {
  case ollama
  case openai
  case gemini
  case anthropic

  var displayName: String {
    switch self {
    case .ollama:
      return "Ollama"
    case .openai:
      return "OpenAI"
    case .gemini:
      return "Gemini"
    case .anthropic:
      return "Anthropic"
    }
  }
}

@Model
final class ChatModel: Identifiable, Equatable, Hashable {
  var name: String
  var displayName: String
  var provider: LLMProvider
  var lastUsed: Date?
  var enabled: Bool

  var defaultTemperature: Double?
  var defaultSystemPrompt: String?
  var defaultTopP: Double?
  var defaultMaxTokens: Int?

  var id: String { name }

  init(
    name: String,
    provider: LLMProvider,
    lastUsed: Date? = nil,
    enabled: Bool = true,
    displayName: String? = nil,
    defaultTemperature: Double? = nil,
    defaultSystemPrompt: String? = nil,
    defaultTopP: Double? = nil,
    defaultMaxTokens: Int? = nil
  ) {
    self.name = name
    self.provider = provider
    self.lastUsed = lastUsed
    self.enabled = enabled
    self.displayName = displayName ?? name
    self.defaultTemperature = defaultTemperature
    self.defaultSystemPrompt = defaultSystemPrompt
    self.defaultTopP = defaultTopP
    self.defaultMaxTokens = defaultMaxTokens
  }

  nonisolated func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }

  static func == (lhs: ChatModel, rhs: ChatModel) -> Bool {
    lhs.id == rhs.id
      && lhs.displayName == rhs.displayName && lhs.provider == rhs.provider && lhs.lastUsed == rhs.lastUsed
      && lhs.enabled == rhs.enabled
      && lhs.defaultTemperature == rhs.defaultTemperature
      && lhs.defaultSystemPrompt == rhs.defaultSystemPrompt && lhs.defaultTopP == rhs.defaultTopP
      && lhs.defaultMaxTokens == rhs.defaultMaxTokens
  }
}
