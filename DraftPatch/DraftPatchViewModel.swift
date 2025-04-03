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
  @Published var availableModels: [ChatModel] = [] {
    didSet {
      if selectedModel == nil, !availableModels.isEmpty {
        selectedModel = availableModels.first
      }
    }
  }
  @Published var selectedModel: ChatModel? = nil
  @Published var thinking: Bool = false
  @Published var showSettings: Bool = false
  @Published var chatBoxFocused: Bool = true
  @Published var lastUserMessageID: UUID?

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

  var isAwaitingResponse: Bool {
    guard let thread = selectedThread, let lastMessage = thread.messages.last else { return false }
    return lastMessage.role == .assistant && lastMessage.streaming && lastMessage.text.isEmpty
  }

  init(repository: DraftPatchRepository, llmManager: LLMManager = LLMManager.shared) {
    self.repository = repository
    self.llmManager = llmManager

    loadModels()
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
      selectedModel = settings?.defaultModel ?? availableModels.first

      if settings != nil, let ollamaEndpontURL = settings?.ollamaConfig?.endpointURL {
        OllamaService.shared.endpointURL = ollamaEndpontURL
      }
    } catch {
      print("Error loading settings: \(error)")
    }
  }

  func loadModels() {
    do {
      availableModels = try repository.fetchModels() ?? []
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
    let models = await llmManager.loadLLMs(settings, existingModels: availableModels)

    do {
      for model in models {
        try repository.insertModel(model)
      }
      try repository.save()

      self.availableModels = models
    } catch {
      print("Error saving models: \(error)")
    }
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
    guard let model = defaultModel ?? availableModels.first else { return }
    let thread = ChatThread(
      title: title,
      model: model
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
    guard let currentModel = selectedModel ?? availableModels.first else { return }

    if let model = availableModels.first(where: { $0.id == currentModel.id }) {
      model.lastUsed = Date()
      thread.model = model
    }

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
          <userSelectedCode>

          ```\(ext)
          \(selectedText)
          ```

          </userSelectedCode>
          """
      } else {
        messageText = text
      }
    } else if let selectedText, !selectedText.isEmpty {
      let ext = fileExtension ?? "txt"
      messageText = """
        <userSelectedCode>

        ```\(ext)
        \(selectedText)
        ```

        </userSelectedCode>
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
    lastUserMessageID = userMsg.id

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
        chatThreads = chatThreads.sorted { $0.updatedAt > $1.updatedAt }
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
