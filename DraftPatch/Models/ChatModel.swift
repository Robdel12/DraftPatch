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
class ChatModel: Identifiable, Equatable {
  var name: String
  var provider: LLMProvider
  var lastUsed: Date? = nil

  var id: String { name }

  init(name: String, provider: LLMProvider, lastUsed: Date? = nil) {
    self.name = name
    self.provider = provider
    self.lastUsed = Date()
  }

  static func == (lhs: ChatModel, rhs: ChatModel) -> Bool {
    return lhs.name == rhs.name && lhs.provider == rhs.provider
  }
}
