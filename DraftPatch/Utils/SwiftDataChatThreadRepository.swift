//
//  SwiftDataChatThreadRepository.swift
//  DraftPatch
//
//  Created by Robert DeLuca on 3/11/25.
//

import Foundation
import SwiftData

class SwiftDataChatThreadRepository: ChatThreadRepository {
  private var context: ModelContext

  init(context: ModelContext) {
    self.context = context
  }

  func fetchThreads() throws -> [ChatThread] {
    let descriptor = FetchDescriptor<ChatThread>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
    return try context.fetch(descriptor)
  }

  func fetchSettings() throws -> Settings? {
    let descriptor = FetchDescriptor<Settings>()
    return try context.fetch(descriptor).first
  }

  func insertThread(_ thread: ChatThread) throws {
    context.insert(thread)
  }

  func save() throws {
    try context.save()
  }

  func deleteThread(_ thread: ChatThread) throws {
    context.delete(thread)
  }
}
