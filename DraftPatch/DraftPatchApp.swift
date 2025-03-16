//
//  DraftPatchApp.swift
//  DraftPatch
//
//  Created by Robert DeLuca on 2/25/25.
//

import SwiftData
import SwiftUI

@main
struct DraftPatchApp: App {
  private var modelContainer: ModelContainer
  @StateObject private var viewModel: DraftPatchViewModel

  init() {
    self.modelContainer = Self.setupModelContainer(retryOnFailure: true)
    let ctx = ModelContext(self.modelContainer)
    let repository = SwiftDataDraftPatchRepository(context: ctx)

    if ProcessInfo.processInfo.arguments.contains("UI_TEST_MODE") {
      _viewModel = StateObject(
        wrappedValue: DraftPatchViewModel(
          repository: repository,
          llmManager: MockLLMManager()
        )
      )
    } else {
      _viewModel = StateObject(wrappedValue: DraftPatchViewModel(repository: repository))
    }

    // Request accessibility permissions for drafting
    DraftingService.shared.checkAccessibilityPermission()
  }

  private static func setupModelContainer(retryOnFailure: Bool) -> ModelContainer {
    do {
      let schema = Schema([
        ChatThread.self,
        ChatMessage.self,
        Settings.self,
      ])

      let configuration = ModelConfiguration(
        schema: schema,
        isStoredInMemoryOnly: ProcessInfo.processInfo.arguments.contains("UI_TEST_MODE")
      )

      return try ModelContainer(
        for: ChatThread.self, ChatMessage.self, Settings.self,
        configurations: configuration
      )
    } catch {
      print("Error creating ModelContainer: \(error)")
      if retryOnFailure {
        print("Deleting store and retrying...")
        let storeURL = URL(fileURLWithPath: "\(NSHomeDirectory())/Library/Application Support/default.store")
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: storeURL.path) {
          do {
            try fileManager.removeItem(at: storeURL)
            print("Deleted existing store at: \(storeURL)")
          } catch {
            print("Failed to delete store: \(error)")
          }
        }
        return setupModelContainer(retryOnFailure: false)
      } else {
        fatalError("Failed to initialize model container after retrying.")
      }
    }
  }

  var body: some Scene {
    WindowGroup {
      RootView()
        .modelContainer(modelContainer)
        .environmentObject(viewModel)
        .preferredColorScheme(.dark)
    }
    .commands {
      DraftPatchCommands(viewModel: viewModel)
    }
  }
}
