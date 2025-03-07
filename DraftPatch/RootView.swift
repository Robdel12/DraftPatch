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

  @State private var showSettings: Bool = false

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
                  thread == viewModel.selectedThread && !showSettings
                    ? Color.accentColor.opacity(0.2)
                    : Color.clear
                )
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .contextMenu {
              Button(role: .destructive) {
                viewModel.deleteThread(thread)
              } label: {
                Text("Delete")
              }
            }
          }
        }
      }

      Spacer()

      VStack {
        Button {
          showSettings.toggle()
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
      .background(showSettings ? Color.accentColor.opacity(0.2) : Color.clear)
    } detail: {
      NavigationStack {
        ChatView(isTextFieldFocused: $isTextFieldFocused)
          .environmentObject(viewModel)
          .navigationDestination(isPresented: $showSettings) {
            SettingsView()
          }
      }
    }
    .navigationTitle("")
    .toolbar {
      ToolbarItem(placement: .navigation) {
        if let thread = viewModel.selectedThread, !showSettings {
          RenamableTitleView(thread: thread)
        }
      }

      if !showSettings {
        ToolbarItem(placement: .automatic) {
          Picker("Model", selection: $viewModel.selectedModel) {
            ForEach(viewModel.availableModels, id: \.id) { model in
              Text(model.name).tag(model)
            }
          }
          .pickerStyle(.menu)
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
