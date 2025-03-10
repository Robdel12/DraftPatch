//
//  ChatModel.swift
//  DraftPatch
//
//  Created by Robert DeLuca on 3/7/25.
//

import Foundation

struct ChatModel: Identifiable, Codable, Hashable, Equatable {
  let name: String
  let provider: LLMProvider

  var id: String { name }

  enum LLMProvider: String, Codable {
    case ollama
    case openai
    case gemini
    case anthropic
  }

  static func == (lhs: ChatModel, rhs: ChatModel) -> Bool {
    return lhs.name == rhs.name && lhs.provider == rhs.provider
  }
}
