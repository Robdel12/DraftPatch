//
//  ChatMessage.swift
//  DraftPatch
//
//  Created by Robert DeLuca on 3/3/25.
//

import Foundation
import SwiftData

@Model
class ChatMessage: Equatable {
  enum Role: String, Codable {
    case user
    case assistant
    case system
  }

  @Attribute(.unique) var id: UUID
  var text: String
  var role: Role
  var timestamp: Date

  init(
    id: UUID = UUID(),
    text: String,
    role: Role,
    timestamp: Date = Date()
  ) {
    self.id = id
    self.text = text
    self.role = role
    self.timestamp = timestamp
  }

  static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
    return lhs.id == rhs.id && lhs.text == rhs.text
  }
}
