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
  var modelName: String
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
    modelName: String,
    messages: [ChatMessage] = []
  ) {
    self.id = id
    self.title = title
    self.createdAt = createdAt
    self.updatedAt = updatedAt
    self.modelName = modelName
    self.messages = messages
  }
}
