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
  @StateObject private var viewModel: ChatViewModel

  init() {
    do {
      let schema = Schema([
        ChatThread.self,
        ChatMessage.self,
      ])

      let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

      self.modelContainer = try ModelContainer(
        for: ChatThread.self, ChatMessage.self,
        configurations: configuration
      )
    } catch {
      fatalError("Error creating ModelContainer: \(error)")
    }

    let ctx = ModelContext(self.modelContainer)
    _viewModel = StateObject(wrappedValue: ChatViewModel(context: ctx))
  }

  var body: some Scene {
    WindowGroup {
      RootView()
        .modelContainer(modelContainer)
        .environmentObject(viewModel)
    }
  }
}
