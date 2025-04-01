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
}

@Model
final class ChatModel: Identifiable, Equatable {
  var name: String
  var displayName: String { name }
  var provider: LLMProvider
  var lastUsed: Date?

  var id: String { name }

  init(name: String, provider: LLMProvider, lastUsed: Date? = nil) {
    self.name = name
    self.provider = provider
    self.lastUsed = lastUsed
  }

  static func == (lhs: ChatModel, rhs: ChatModel) -> Bool {
    return lhs.name == rhs.name
    && lhs.displayName == rhs.displayName
    && lhs.provider == rhs.provider
    && lhs.lastUsed == rhs.lastUsed
  }
}
