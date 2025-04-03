//
//  ChatModel.swift
//  DraftPatch
//
//  Created by Robert DeLuca on 3/7/25.
//

import Foundation
import SwiftData

enum LLMProvider: String, Codable {
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
final class ChatModel: Identifiable, Equatable {
  var name: String
  var displayName: String
  var provider: LLMProvider
  var lastUsed: Date?
  var enabled: Bool

  var id: String { name }

  init(
    name: String, provider: LLMProvider, lastUsed: Date? = nil, enabled: Bool = true,
    displayName: String? = nil
  ) {
    self.name = name
    self.provider = provider
    self.lastUsed = lastUsed
    self.enabled = enabled
    self.displayName = displayName ?? name
  }

  static func == (lhs: ChatModel, rhs: ChatModel) -> Bool {
    return lhs.name == rhs.name
      && lhs.displayName == rhs.displayName
      && lhs.provider == rhs.provider
      && lhs.lastUsed == rhs.lastUsed
  }
}
