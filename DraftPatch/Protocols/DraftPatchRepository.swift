//
//  DraftPatchRepository.swift
//  DraftPatch
//
//  Created by Robert DeLuca on 3/11/25.
//

protocol DraftPatchRepository {
  func save() throws
  func fetchThreads() throws -> [ChatThread]
  func fetchSettings() throws -> Settings?
  func insertThread(_ thread: ChatThread) throws
  func deleteThread(_ thread: ChatThread) throws
  func fetchStoredModels() throws -> [StoredChatModel]
  func insertStoredModel(_ model: StoredChatModel) throws
}
