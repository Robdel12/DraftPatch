//
//  DraftPatchViewModelTests.swift
//  DraftPatch
//
//  Created by Robert DeLuca on 3/12/25.
//

import Foundation
import Testing

@testable import DraftPatch

@MainActor
final class DraftPatchViewModelTests {
  @Test
  func testLoadThreads() {
    let mockRepository = MockChatThreadRepository()
    let viewModel = DraftPatchViewModel(repository: mockRepository)

    #expect(viewModel.chatThreads.isEmpty)

    let thread = ChatThread(title: "Test", model: ChatModel(name: "GPT-4", provider: .openai))
    mockRepository.mockThreads.append(thread)

    viewModel.loadThreads()

    #expect(viewModel.chatThreads.count == 1)
    #expect(viewModel.chatThreads.first?.title == "Test")
    #expect(viewModel.selectedThread == viewModel.chatThreads.first)
  }

  @Test
  func testDeleteThread() {
    let mockRepository = MockChatThreadRepository()
    let viewModel = DraftPatchViewModel(repository: mockRepository)

    let thread1 = ChatThread(title: "Thread 1", model: ChatModel(name: "GPT-4", provider: .openai))
    let thread2 = ChatThread(title: "Thread 2", model: ChatModel(name: "GPT-3.5", provider: .openai))
    mockRepository.mockThreads = [thread1, thread2]

    viewModel.loadThreads()
    viewModel.deleteThread(thread1)

    #expect(viewModel.chatThreads.count == 1)
    #expect(viewModel.chatThreads.first?.title == "Thread 2")
    #expect(viewModel.selectedThread?.title == "Thread 2")
  }

  @Test
  func testToggleDrafting() {
    let mockRepository = MockChatThreadRepository()
    let viewModel = DraftPatchViewModel(repository: mockRepository)

    #expect(!viewModel.isDraftingEnabled)
    #expect(viewModel.selectedDraftApp == nil)

    viewModel.toggleDrafting()

    #expect(viewModel.isDraftingEnabled)
    #expect(viewModel.selectedDraftApp == nil)

    viewModel.toggleDrafting()

    #expect(!viewModel.isDraftingEnabled)
    #expect(viewModel.selectedDraftApp == nil)
  }

  @Test
  func testLoadSettings() {
    let mockRepository = MockChatThreadRepository()
    let mockSettings = Settings()
    mockSettings.ollamaConfig = OllamaConfig(enabled: true, endpointURL: URL(string: "http://example.com")!)
    mockRepository.mockSettings = mockSettings

    let viewModel = DraftPatchViewModel(repository: mockRepository)

    viewModel.loadSettings()

    #expect(viewModel.settings != nil)
    #expect(viewModel.settings?.ollamaConfig?.endpointURL == URL(string: "http://example.com")!)
    #expect(OllamaService.shared.endpointURL == URL(string: "http://example.com")!)
  }

  @Test
  func testCreateDraftThread() {
    let repository = MockChatThreadRepository()
    let viewModel = DraftPatchViewModel(repository: repository)

    viewModel.availableModels = []
    viewModel.createDraftThread(title: "New Draft")
    #expect(viewModel.draftThread == nil)

    let mockModel = ChatModel(name: "GPT-4", provider: .openai)
    viewModel.availableModels = [mockModel]

    viewModel.createDraftThread(title: "New Draft")

    #expect(viewModel.draftThread != nil)
    #expect(viewModel.draftThread?.title == "New Draft")
    #expect(viewModel.draftThread?.model == mockModel)
  }

  @Test
  func testToggleDraftWithLastApp() {
    let mockRepository = MockChatThreadRepository()
    let mockSettings = Settings()
    mockSettings.lastAppDraftedWith = DraftApp(rawValue: "Emacs")
    mockRepository.mockSettings = mockSettings

    let viewModel = DraftPatchViewModel(repository: mockRepository)
    viewModel.loadSettings()

    viewModel.toggleDraftWithLastApp()

    #expect(viewModel.isDraftingEnabled)
    #expect(viewModel.selectedDraftApp?.name == "Emacs")

    viewModel.toggleDraftWithLastApp()

    #expect(!viewModel.isDraftingEnabled)
    #expect(viewModel.selectedDraftApp == nil)
  }
}
