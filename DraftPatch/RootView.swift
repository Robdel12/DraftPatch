//
//  RootView.swift
//  DraftPatch
//
//  Created by Robert DeLuca on 2/25/25.
//

import SwiftData
import SwiftUI

struct RootView: View {
  @EnvironmentObject var viewModel: DraftPatchViewModel
  @FocusState var isTextFieldFocused: Bool

  var body: some View {
    NavigationSplitView {
      List {
        Section("Chats") {
          ForEach(viewModel.chatThreads, id: \.id) { thread in
            Button {
              viewModel.selectedThread = thread
            } label: {
              Text(thread.title)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                  thread == viewModel.selectedThread && !viewModel.showSettings
                    ? Color.accentColor.opacity(0.2)
                    : Color.clear
                )
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("ChatThread_\(thread.title)")
            .contextMenu {
              Button(role: .destructive) {
                viewModel.deleteThread(thread)
              } label: {
                Text("Delete")
              }
              .accessibilityIdentifier("DeleteChatThread_\(thread.title)")
            }
          }
        }
      }
      .accessibilityIdentifier("ChatList")

      Spacer()

      VStack {
        Button {
          viewModel.showSettings.toggle()
        } label: {
          HStack {
            Image(systemName: "gear")
            Text("Settings")
          }
        }
        .buttonStyle(.plain)
        .keyboardShortcut(",", modifiers: .command)
      }
      .padding()
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(viewModel.showSettings ? Color.accentColor.opacity(0.2) : Color.clear)
    } detail: {
      NavigationStack {
        ChatView(isTextFieldFocused: $isTextFieldFocused)
          .environmentObject(viewModel)
          .navigationDestination(isPresented: $viewModel.showSettings) {
            SettingsView()
              .environmentObject(viewModel)
          }
      }
    }
    .navigationTitle("")
    .toolbar {
      ToolbarItem(placement: .navigation) {
        if let thread = viewModel.selectedThread, !viewModel.showSettings {
          RenamableTitleView(thread: thread)
        }
      }

      if !viewModel.showSettings {
        ToolbarItem(placement: .automatic) {
          ModelPickerPopoverView()
            .environmentObject(viewModel)
        }

        ToolbarItem(placement: .primaryAction) {
          Button {
            viewModel.createDraftThread(title: "New Conversation")
            isTextFieldFocused = true
          } label: {
            Label("New Chat", systemImage: "highlighter")
          }
          .keyboardShortcut("n", modifiers: .command)
        }
      }
    }
  }
}
