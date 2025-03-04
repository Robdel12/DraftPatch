//
//  ChatViewModel.swift
//  DraftPatch
//
//  Created by Robert DeLuca on 3/2/25.
//

import SwiftData
import SwiftUI

@MainActor
class ChatViewModel: ObservableObject {
  private var context: ModelContext

  @Published var chatThreads: [ChatThread] = []
  @Published var selectedThread: ChatThread?
  @Published var draftThread: ChatThread? = nil
  @Published var availableModels: [String] = []
  @Published var selectedModelName: String = ""
  @Published var thinking: Bool = false
  @Published var visibleScrollHeight: CGFloat = 0
  @Published var streamingUpdate: UUID = UUID()

  init(context: ModelContext) {
    self.context = context
    loadThreads()
    Task {
      await loadLocalModels()
    }
  }

  func loadLocalModels() async {
    do {
      let models = try await OllamaService.shared.fetchAvailableModels()
      self.availableModels = models

      if let firstModel = models.first {
        self.selectedModelName = firstModel
      } else {
        self.selectedModelName = "No Models Found"
      }
    } catch {
      print("Error loading models: \(error)")
    }
  }

  private func loadThreads() {
    let descriptor = FetchDescriptor<ChatThread>(
      sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
    )
    do {
      chatThreads = try context.fetch(descriptor)
      selectedThread = chatThreads.sorted(by: { $0.updatedAt > $1.updatedAt }).first
    } catch {
      print("Error loading threads: \(error)")
      chatThreads = []
      selectedThread = nil
    }
  }

  /// Create a new ephemeral thread in memory, but do **not** persist it yet.
  func createDraftThread(title: String) {
    let defaultModel = availableModels.first ?? "llama3.2"
    let thread = ChatThread(title: title, modelName: defaultModel)
    draftThread = thread

    selectedThread = draftThread
  }

  // Change the model for the currently selected thread
  func setModelForCurrentThread(_ modelName: String) {
    guard let thread = selectedThread else { return }
    thread.modelName = modelName
    saveContext()
  }

  /// Handle sending a message. If we’re currently working with a draft,
  /// we insert that draft into the context before persisting the message.
  func sendMessage(_ text: String) async {
    guard let thread = selectedThread else { return }

    if let draftThread, draftThread == thread {
      context.insert(thread)
      do {
        try context.save()
        chatThreads.insert(thread, at: 0)
      } catch {
        print("Error saving new thread: \(error)")
        return
      }
      self.draftThread = nil
    }

    let userMsg = ChatMessage(text: text, role: .user)
    thread.messages.append(userMsg)
    saveContext()

    let messagesPayload = thread.messages.map { msg -> [String: Any] in
      [
        "role": msg.role.rawValue,
        "content": msg.text,
      ]
    }

    let tokenStream = OllamaService.shared.streamChat(
      messages: messagesPayload,
      modelName: thread.modelName
    )

    thinking = true

    let assistantMsg = ChatMessage(text: "", role: .assistant, streaming: true)
    thread.messages.append(assistantMsg)
    saveContext()

    do {
      for try await partialText in tokenStream {
        assistantMsg.text += partialText
        saveContext()
        streamingUpdate = UUID()
      }

      // Mark completion
      assistantMsg.streaming = false
      thread.updatedAt = Date()
      saveContext()

      // If it was a brand new conversation, generate a title asynchronously
      if thread.title == "New Conversation" {
        do {
          let title = try await OllamaService.shared.generateTitle(
            for: text,
            modelName: thread.modelName
          )
          thread.title = title
          saveContext()
        } catch {
          print("Error generating thread title: \(error)")
        }
      }
    } catch {
      print("Error during streaming: \(error)")
      thinking = false
      assistantMsg.streaming = false
      saveContext()
    }

    thinking = false
  }

  private func saveContext() {
    do {
      try context.save()
      objectWillChange.send()
    } catch {
      print("Error saving context: \(error)")
    }
  }

  func deleteThread(_ thread: ChatThread) {
    context.delete(thread)

    do {
      try context.save()

      if let index = chatThreads.firstIndex(where: { $0.id == thread.id }) {
        chatThreads.remove(at: index)
      }

      if selectedThread == thread {
        selectedThread = chatThreads.first
      }
    } catch {
      print("Error deleting thread: \(error)")
    }
  }
}
