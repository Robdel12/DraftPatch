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
  private var repository: DraftPatchRepository
  private var llmManager: LLMManager

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
  @Published var showSettings: Bool = false

  @Published var isDraftingEnabled: Bool = false
  @Published var selectedDraftApp: DraftApp? = nil {
    didSet {
      if let appSettings = settings, selectedDraftApp != nil {
        appSettings.lastAppDraftedWith = selectedDraftApp
      }
    }
  }
  @Published var settings: Settings? = nil
  @Published var errorMessage: String? = nil

  init(repository: DraftPatchRepository, llmManager: LLMManager = LLMManager.shared) {
    self.repository = repository
    self.llmManager = llmManager

    loadSettings()
    loadThreads()

    Task {
      await loadLLMs()
    }
  }

  func loadThreads() {
    do {
      chatThreads = try repository.fetchThreads()
      selectedThread = chatThreads.first
    } catch {
      print("Error loading threads: \(error)")
      chatThreads = []
      selectedThread = nil
    }
  }

  func loadSettings() {
    do {
      settings = try repository.fetchSettings()

      if settings != nil, let ollamaEndpontURL = settings?.ollamaConfig?.endpointURL {
        OllamaService.shared.endpointURL = ollamaEndpontURL
      }
    } catch {
      print("Error loading settings: \(error)")
    }
  }

  func deleteThread(_ thread: ChatThread) {
    do {
      try repository.deleteThread(thread)
      try repository.save()

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

  func toggleDrafting() {
    isDraftingEnabled.toggle()

    if !isDraftingEnabled {
      selectedDraftApp = nil
    }
  }

  func loadLLMs() async {
    do {
      let storedModels = try repository.fetchStoredModels()
      self.availableModels = storedModels.map { ChatModel(name: $0.name, provider: $0.provider) }
    } catch {
      print("Error loading stored models: \(error)")
    }

    let fetchedModels = await llmManager.loadLLMs(settings)

    do {
      for model in fetchedModels {
        if !self.availableModels.contains(where: { $0.name == model.name && $0.provider == model.provider }) {
          let storedModel = StoredChatModel(name: model.name, provider: model.provider)
          try repository.insertStoredModel(storedModel)
        }
      }
    } catch {
      print("Error saving fetched models: \(error)")
    }

    self.availableModels = fetchedModels
  }

  func toggleDraftWithLastApp() {
    if isDraftingEnabled {
      isDraftingEnabled = false
      selectedDraftApp = nil
    } else {
      isDraftingEnabled = true
      if let lastAppDraftedWith = settings?.lastAppDraftedWith {
        selectedDraftApp = lastAppDraftedWith
      } else {
        selectedDraftApp = DraftApp(rawValue: "Xcode")
      }
    }
  }

  /// Create a new ephemeral thread in memory, but do **not** persist it yet.
  func createDraftThread(title: String) {
    let defaultModel = settings?.defaultModel
    let thread = ChatThread(
      title: title,
      model: defaultModel ?? ChatModel(name: "Default", provider: .ollama)
    )
    draftThread = thread
    selectedThread = draftThread
  }

  func cancelStreamingMessage() {
    if let thread = selectedThread {
      llmManager.getService(for: thread.model.provider).cancelStreamChat()
    }
  }

  /// Handle sending a message. If we’re currently working with a draft,
  /// we insert that draft into the context before persisting the message.
  func sendMessage(_ text: String? = nil) async {
    guard let thread = selectedThread else { return }
    thread.model = selectedModel

    // Fetch selected text if a DraftApp is selected
    let selectedText = selectedDraftApp.flatMap { draftApp in
      DraftingService.shared.getSelectedOrViewText(appIdentifier: draftApp.id)
    }

    // Fetch file extension if a DraftApp is selected
    let fileExtension = selectedDraftApp.flatMap { draftApp in
      DraftingService.shared.getCurrentFileExtension(appIdentifier: draftApp.id)
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

    // If we're working with a draft thread, persist it
    if let draftThread, draftThread == thread {
      do {
        try repository.insertThread(thread)
        try repository.save()
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

      // Create an assistant message to hold the streaming text
      let assistantMsg = ChatMessage(text: "", role: .assistant, streaming: true)
      thread.messages.append(assistantMsg)

      // Use a buffer to batch updates
      var textBuffer = ""
      var updateTimer: Timer?

      Task {
        var firstLoop = true
        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { _ in
          DispatchQueue.main.async {
            if !textBuffer.isEmpty {
              assistantMsg.text += textBuffer
              textBuffer = ""
            }
          }
        }

        do {
          for try await partialText in tokenStream {
            if firstLoop {
              firstLoop = false
              thread.updatedAt = Date()
            }

            textBuffer += partialText
          }

          // Ensure the final buffered text is added
          DispatchQueue.main.async {
            assistantMsg.text += textBuffer
            assistantMsg.streaming = false
          }

          updateTimer?.invalidate()

          // Save the thread *after* the streaming is complete
          try repository.save()

          if thread.title == "New Conversation" {
            do {
              let title = try await generateTitle(for: messageText, using: thread.model)
              thread.title = title
              try repository.save()
            } catch {
              print("Error generating thread title: \(error)")
            }
          }
        } catch {
          print("Error during streaming: \(error)")
          errorMessage = error.localizedDescription
        }

        thinking = false
      }
    }
  }

  /// Determines the correct service and returns a token stream.
  private func getTokenStream(for thread: ChatThread, with messages: [ChatMessagePayload])
    -> AsyncThrowingStream<String, Error>?
  {
    return llmManager.getService(for: thread.model.provider)
      .streamChat(messages: messages, modelName: thread.model.name)
  }

  /// Calls the appropriate service to generate a title based on the provider.
  private func generateTitle(for text: String, using model: ChatModel) async throws -> String {
    return try await llmManager.getService(for: model.provider)
      .generateTitle(for: text, modelName: model.name)
  }
}
