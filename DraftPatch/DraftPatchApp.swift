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
  private let modelContainer: ModelContainer
  @StateObject private var viewModel: DraftPatchViewModel

  init() {
    do {
      let schema = Schema([
        ChatThread.self,
        ChatMessage.self,
        Settings.self,
      ])

      let configuration = ModelConfiguration(
        schema: schema,
        isStoredInMemoryOnly: false
      )

      self.modelContainer = try ModelContainer(
        for: ChatThread.self, ChatMessage.self, Settings.self,
        configurations: configuration
      )
    } catch {
      fatalError("Error creating ModelContainer: \(error)")
    }

    let ctx = ModelContext(self.modelContainer)
    let repository = SwiftDataChatThreadRepository(context: ctx)
    _viewModel = StateObject(wrappedValue: DraftPatchViewModel(repository: repository))

    // Request accessibility permissions for drafting
    DraftingService.shared.checkAccessibilityPermission()
  }

  var body: some Scene {
    WindowGroup {
      RootView()
        .modelContainer(modelContainer)
        .environmentObject(viewModel)
        .preferredColorScheme(.dark)
    }
  }
}
