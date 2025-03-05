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
  @State private var userMessage = ""

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
                  thread == viewModel.selectedThread
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
    } detail: {
      if let thread = viewModel.selectedThread {
        VStack {
          Divider()

          ScrollView {
            LazyVStack(spacing: 8) {
              ForEach(
                thread.messages.sorted(by: { $0.timestamp < $1.timestamp }),
                id: \.id
              ) { msg in
                ChatMessageRow(message: msg)
                  .id(msg.id)
                  .environmentObject(viewModel)
              }

              Rectangle()
                .fill(Color.clear)
                .frame(width: 1, height: 1)
                .id("bottom")
            }
            .padding()
          }
          .defaultScrollAnchor(.bottom)

          ChatBoxView(
            userMessage: $userMessage,
            selectedDraftApp: $viewModel.selectedDraftApp,
            thinking: viewModel.thinking,
            onSubmit: sendMessage
          )
          .padding(.horizontal)
        }
        .padding(.bottom, 12)
        .background(Color(.black).opacity(0.2))
      } else {
        VStack(spacing: 16) {
          Image(systemName: "flag.checkered")
            .resizable()
            .scaledToFit()
            .frame(width: 80, height: 80)
            .foregroundStyle(.secondary)

          Text("No chat selected")
            .font(.title2)
            .bold()

          Text("Select a chat and start drafting!")
            .multilineTextAlignment(.center)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.black).opacity(0.1))
      }
    }
    .navigationTitle("")
    .toolbar {
      ToolbarItem(placement: .navigation) {
        if let thread = viewModel.selectedThread {
          RenamableTitleView(thread: thread)
        }
      }

      ToolbarItem(placement: .automatic) {
        Picker("Model", selection: $viewModel.selectedModelName) {
          ForEach(viewModel.availableModels, id: \.self) { model in
            Text(model)
          }
        }
        .pickerStyle(.menu)
      }

      ToolbarItem(placement: .primaryAction) {
        Button {
          viewModel.createDraftThread(title: "New Conversation")
        } label: {
          Label("New Chat", systemImage: "highlighter")
        }
        .keyboardShortcut("n", modifiers: .command)
      }
    }
  }

  private func sendMessage() {
    let textToSend = userMessage.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !textToSend.isEmpty else { return }

    Task {
      await viewModel.sendMessage(textToSend)
    }
    userMessage = ""
  }
}
