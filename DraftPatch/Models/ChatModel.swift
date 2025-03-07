//
//  ChatModel.swift
//  DraftPatch
//
//  Created by Robert DeLuca on 3/7/25.
//

import Foundation

struct ChatModel: Identifiable, Codable, Hashable {
  let name: String
  let provider: LLMProvider

  var id: String { name }

  enum LLMProvider: String, Codable {
    case ollama
    case openai
  }
}
