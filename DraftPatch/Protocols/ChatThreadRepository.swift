//
//  ChatThreadRepository.swift
//  DraftPatch
//
//  Created by Robert DeLuca on 3/11/25.
//

protocol ChatThreadRepository {
  func fetchThreads() throws -> [ChatThread]
  func fetchSettings() throws -> Settings?
  func insertThread(_ thread: ChatThread) throws
  func save() throws
  func deleteThread(_ thread: ChatThread) throws
}
