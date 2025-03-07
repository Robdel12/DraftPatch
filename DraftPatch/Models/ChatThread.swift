//
//  ChatThread.swift
//  DraftPatch
//
//  Created by Robert DeLuca on 3/2/25.
//

import Foundation
import SwiftData

@Model
class ChatThread: ObservableObject {
  @Attribute(.unique) var id: UUID
  var title: String
  var createdAt: Date
  var updatedAt: Date
  var model: ChatModel
  var messages: [ChatMessage] {
    didSet {
      updatedAt = Date()
    }
  }

  init(
    id: UUID = UUID(),
    title: String,
    createdAt: Date = Date(),
    updatedAt: Date = Date(),
    model: ChatModel,
    messages: [ChatMessage] = []
  ) {
    self.id = id
    self.title = title
    self.createdAt = createdAt
    self.updatedAt = updatedAt
    self.model = model
    self.messages = messages
  }
}
