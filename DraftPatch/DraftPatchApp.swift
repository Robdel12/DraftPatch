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
    self.modelContainer = try! Self.setupModelContainer()
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

  private static func setupModelContainer() throws -> ModelContainer {
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
        for: ChatThread.self,
        ChatMessage.self,
        Settings.self,
        configurations: configuration
      )
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
