//
//  ChatViewModel.swift
//  DraftPatch
//
//  Created by Robert DeLuca on 3/2/25.
//

import SwiftData
import SwiftUI

@MainActor
class DraftPatchViewModel: ObservableObject {
  private var context: ModelContext

  @Published var chatThreads: [ChatThread] = []
  @Published var selectedThread: ChatThread? {
    didSet {
      if let model = selectedThread?.model {
        selectedModel = model
      }
    }
  }
  @Published var draftThread: ChatThread? = nil
  @Published var availableModels: [ChatModel] = []
  @Published var selectedModel: ChatModel = ChatModel(name: "Default", provider: .ollama)
  @Published var thinking: Bool = false
  @Published var visibleScrollHeight: CGFloat = 0
  @Published var streamingUpdate: UUID = UUID()

  @Published var isDraftingEnabled: Bool = false
  @Published var selectedDraftApp: DraftApp? = nil
  @Published var settings: Settings? = nil

  init(context: ModelContext) {
    self.context = context

    loadSettings()
    loadThreads()

    Task {
      await loadLLMs()
    }
  }

  func toggleDrafting() {
    isDraftingEnabled.toggle()

    if !isDraftingEnabled {
      selectedDraftApp = nil
    }
  }

  func loadLLMs() async {
    await loadOllamaModels()
    await loadOpenAIModels()
    await loadGeminiModels()
  }

  func loadOllamaModels() async {
    do {
      let models = try await OllamaService.shared.fetchAvailableModels()
      self.availableModels = models.map { ChatModel(name: $0, provider: .ollama) }
    } catch {
      print("Error loading Ollama models: \(error)")
    }
  }

  func loadOpenAIModels() async {
    guard settings?.isOpenAIEnabled ?? false else { return }

    do {
      let models = try await OpenAIService.shared.fetchAvailableModels()
      let openAIModels = models.map { ChatModel(name: $0, provider: .openai) }

      self.availableModels += openAIModels
    } catch {
      print("Error loading OpenAI models: \(error)")
    }
  }

  func loadGeminiModels() async {
    guard settings?.isGeminiEnabled ?? false else { return }

    do {
      let models = try await GeminiService.shared.fetchAvailableModels()
      let geminiModels = models.map { ChatModel(name: $0, provider: .gemini) }

      self.availableModels += geminiModels
    } catch {
      print("Error loading Gemini models: \(error)")
    }
  }

  private func loadThreads() {
    let descriptor = FetchDescriptor<ChatThread>(
      sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
    )

    do {
      chatThreads = try context.fetch(descriptor)
      selectedThread = chatThreads.first
    } catch {
      print("Error loading threads: \(error)")
      chatThreads = []
      selectedThread = nil
    }
  }

  private func loadSettings() {
    let descriptor = FetchDescriptor<Settings>()

    do {
      settings = try context.fetch(descriptor).first
    } catch {
      print("Error loading settings: \(error)")
    }
  }

  /// Create a new ephemeral thread in memory, but do **not** persist it yet.
  func createDraftThread(title: String) {
    let defaultModel = availableModels.first
    let thread = ChatThread(
      title: title,
      model: defaultModel ?? ChatModel(name: "Default", provider: .ollama)
    )
    draftThread = thread
    selectedThread = draftThread
  }

  /// Handle sending a message. If we’re currently working with a draft,
  /// we insert that draft into the context before persisting the message.
  func sendMessage(_ text: String? = nil) async {
    guard let thread = selectedThread else { return }
    thread.model = selectedModel

    // Fetch selected text if a DraftApp is selected
    let selectedText = selectedDraftApp.flatMap { draftApp in
      DraftingSerivce.shared.getSelectedOrActiveText(appIdentifier: draftApp.id)
    }

    // Fetch file extension if a DraftApp is selected
    let fileExtension = selectedDraftApp.flatMap { draftApp in
      DraftingSerivce.shared.getCurrentFileExtension(appIdentifier: draftApp.id)
    }?.replacingOccurrences(of: ".", with: "")

    // Format the message: append selected text if available
    let messageText: String
    if let text = text, !text.isEmpty {
      if let selectedText, !selectedText.isEmpty {
        let ext = fileExtension ?? "txt"
        messageText = """
          \(text)

          ---
          ```\(ext)
          \(selectedText)
          ```
          """
      } else {
        messageText = text
      }
    } else if let selectedText, !selectedText.isEmpty {
      let ext = fileExtension ?? "txt"
      messageText = """
        ```\(ext)
        \(selectedText)
        ```
        """
    } else {
      return
    }

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

    let userMsg = ChatMessage(text: messageText, role: .user)
    thread.messages.append(userMsg)

    let messagesPayload = thread.messages.map { msg in
      ChatMessagePayload(role: msg.role, content: msg.text)
    }

    if let tokenStream = getTokenStream(for: thread, with: messagesPayload) {
      thinking = true
      saveContext()

      let assistantMsg = ChatMessage(text: "", role: .assistant, streaming: true)
      thread.messages.append(assistantMsg)

      do {
        var firstLoop = true

        for try await partialText in tokenStream {
          if firstLoop {
            firstLoop = false
            thread.updatedAt = Date()
          }

          assistantMsg.text += partialText
          streamingUpdate = UUID()
        }

        assistantMsg.streaming = false
        saveContext()

        if thread.title == "New Conversation" {
          do {
            let title = try await generateTitle(for: messageText, using: thread.model)
            thread.title = title
            saveContext()
          } catch {
            print("Error generating thread title: \(error)")
          }
        }
      } catch {
        print("Error during streaming: \(error)")
      }

      thinking = false
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

  /// Determines the correct service and returns a token stream.
  private func getTokenStream(for thread: ChatThread, with messages: [ChatMessagePayload])
    -> AsyncThrowingStream<String, Error>?
  {
    switch thread.model.provider {
    case .ollama:
      return OllamaService.shared.streamChat(
        messages: messages,
        modelName: thread.model.name
      )
    case .openai:
      return OpenAIService.shared.streamChat(
        messages: messages,
        modelName: thread.model.name
      )
    case .gemini:
      return GeminiService.shared.streamChat(
        messages: messages,
        modelName: thread.model.name
      )
    }
  }

  /// Calls the appropriate service to generate a title based on the provider.
  private func generateTitle(for text: String, using model: ChatModel) async throws -> String {
    switch model.provider {
    case .ollama:
      return try await OllamaService.shared.generateTitle(for: text, modelName: model.name)
    case .openai:
      return try await OpenAIService.shared.generateTitle(for: text, modelName: model.name)
    case .gemini:
      return try await GeminiService.shared.generateTitle(for: text, modelName: model.name)
    }
  }
}
