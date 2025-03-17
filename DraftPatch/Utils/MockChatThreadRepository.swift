//
//  MockChatThreadRepository.swift
//  DraftPatch
//
//  Created by Robert DeLuca on 3/11/25.
//

class MockChatThreadRepository: DraftPatchRepository {
  var mockThreads: [ChatThread] = []
  var mockSettings: Settings? = nil
  var mockStoredModels: [ChatModel] = []

  func fetchThreads() throws -> [ChatThread] {
    return mockThreads
  }

  func fetchSettings() throws -> Settings? {
    return mockSettings
  }

  func fetchModels() throws -> [ChatModel]? {
    return mockStoredModels
  }

  func insertModel(_ model: ChatModel) throws {
    mockStoredModels.append(model)
  }

  func insertThread(_ thread: ChatThread) throws {
    mockThreads.append(thread)
  }

  func save() throws {}

  func deleteThread(_ thread: ChatThread) throws {
    mockThreads.removeAll { $0.id == thread.id }
  }

  func insertStoredModel(_ model: ChatModel) throws {
    mockStoredModels.append(model)
  }
}
