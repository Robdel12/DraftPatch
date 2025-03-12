//
//  ChatMessage.swift
//  DraftPatch
//
//  Created by Robert DeLuca on 3/3/25.
//

import Foundation
import SwiftData

enum Role: String, Codable {
  case user = "user"
  case assistant = "assistant"
  case system = "system"
}

@Model
final class ChatMessage: Equatable, @unchecked Sendable {
  @Attribute(.unique) var id: UUID
  var text: String
  var role: Role
  var timestamp: Date
  var streaming: Bool = false

  init(
    id: UUID = UUID(),
    text: String,
    role: Role,
    timestamp: Date = Date(),
    streaming: Bool = false
  ) {
    self.id = id
    self.text = text
    self.role = role
    self.timestamp = timestamp
    self.streaming = streaming
  }

  static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
    return lhs.id == rhs.id && lhs.text == rhs.text
  }
}
