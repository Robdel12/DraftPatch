//
//  DraftPatchCommands.swift
//  DraftPatch
//
//  Created by Robert DeLuca on 3/12/25.
//

import SwiftUI

struct DraftPatchCommands: Commands {
  @ObservedObject var viewModel: DraftPatchViewModel

  var body: some Commands {
    CommandGroup(after: .newItem) {
      Button("New Chat") {
        viewModel.createDraftThread(title: "New Conversation")
      }
      .keyboardShortcut("n", modifiers: .command)
    }

    CommandGroup(before: .textEditing) {
      Button("Toggle Drafting") {
        viewModel.toggleDrafting()
      }
      .keyboardShortcut("d", modifiers: .command)
    }
    
    CommandGroup(before: .textEditing) {
      Button("Select Model") {
        // Hacky, letting it fall through to the pickers shortcut modifier
        // TODO: Move popover state to view model?
      }
      .keyboardShortcut("e", modifiers: .command)
    }

    CommandGroup(replacing: .appSettings) {
      Button("Settings...") {
        viewModel.showSettings.toggle()
      }
      .keyboardShortcut(",", modifiers: .command)
    }
  }
}
