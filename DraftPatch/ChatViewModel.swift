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
  @Published var availableModels: [String] = []

  // New properties to track streaming state and trigger UI updates
  @Published var thinking: Bool = false
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
    } catch {
      print("Error loading models: \(error)")
    }
  }

  private func loadThreads() {
    let descriptor = FetchDescriptor<ChatThread>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
    do {
      chatThreads = try context.fetch(descriptor)
      selectedThread = chatThreads.sorted(by: { $0.updatedAt > $1.updatedAt }).first
    } catch {
      print("Error loading threads: \(error)")
      chatThreads = []
      selectedThread = nil
    }
  }

  func createNewThread(title: String) {
    let defaultModel = availableModels.first ?? "llama3.2"
    let thread = ChatThread(title: title, modelName: defaultModel)
    context.insert(thread)

    do {
      try context.save()
      chatThreads.insert(thread, at: 0)
      selectedThread = thread
    } catch {
      print("Error saving new thread: \(error)")
    }
  }

  // Change the model for the currently selected thread
  func setModelForCurrentThread(_ modelName: String) {
    guard let thread = selectedThread else { return }
    thread.modelName = modelName
    saveContext()
  }

  // Append a message from the user, call Ollama, and stream the assistant response
  func sendMessage(_ text: String) async {
    guard let thread = selectedThread else { return }

    let userMsg = ChatMessage(text: text, role: .user)
    thread.messages.append(userMsg)
    saveContext()

    let messagesPayload = thread.messages.map { msg -> [String: Any] in
      return [
        "role": msg.role.rawValue,
        "content": msg.text,
      ]
    }

    let tokenStream = OllamaService.shared.streamChat(
      messages: messagesPayload,
      modelName: thread.modelName
    )

    // Signal that the assistant is "thinking" (streaming response)
    thinking = true

    let assistantMsg = ChatMessage(text: "", role: .assistant)
    thread.messages.append(assistantMsg)
    saveContext()

    // As tokens stream in, update the assistant message text and trigger UI updates.
    for await partialText in tokenStream {
      assistantMsg.text += partialText
      saveContext()
      streamingUpdate = UUID()  // each update triggers onChange in the UI to scroll to bottom
    }

    // Stop the streaming state
    thinking = false

    // If it's a new conversation, generate a title
    if thread.title == "New Conversation" {
      do {
        let title = try await OllamaService.shared.generateTitle(for: text, modelName: thread.modelName)
        thread.title = title
        saveContext()
      } catch {
        print("Error generating thread title: \(error)")
      }
    }
  }

  private func saveContext() {
    do {
      try context.save()
      objectWillChange.send()
    } catch {
      print("Error saving context: \(error)")
    }
  }
}
