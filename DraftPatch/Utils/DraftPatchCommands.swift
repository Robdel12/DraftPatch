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
      Button("Toggle drafting") {
        viewModel.toggleDrafting()
      }
      .keyboardShortcut("d", modifiers: .command)
    }
    
    CommandGroup(before: .textEditing) {
      Button("Select model") {
        // Hacky, letting it fall through to the pickers shortcut modifier
        // TODO: Move popover state to view model?
      }
      .keyboardShortcut("e", modifiers: .command)
    }

    CommandGroup(replacing: .appSettings) {
      Button("Preferences...") {
        viewModel.showSettings.toggle()
      }
      .keyboardShortcut(",", modifiers: .command)
    }
  }
}
