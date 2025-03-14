//
//  StoredChatModel.swift
//  DraftPatch
//
//  Created by Robert DeLuca on 3/14/25.
//

import Foundation
import SwiftData

@Model
class StoredChatModel: Identifiable {
  var id: UUID
  var name: String
  var provider: ChatModel.LLMProvider

  init(name: String, provider: ChatModel.LLMProvider) {
    self.id = UUID()
    self.name = name
    self.provider = provider
  }
}
