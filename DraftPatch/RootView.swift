//
//  RootView.swift
//  DraftPatch
//
//  Created by Robert DeLuca on 2/25/25.
//

import SwiftData
import SwiftUI

struct RootView: View {
  @EnvironmentObject var viewModel: ChatViewModel
  @State private var userMessage = ""
  @FocusState private var isTextFieldFocused: Bool
  @State private var scrollProxy: ScrollViewProxy?

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

          HStack(spacing: 8) {
            TextField("Draft a message", text: $userMessage, axis: .vertical)
              .lineLimit(4, reservesSpace: true)
              .font(.system(size: 14))
              .textFieldStyle(.plain)
              .padding()
              .background(
                RoundedRectangle(cornerRadius: 8)
                  .fill(Color(.secondarySystemFill))
              )
              .cornerRadius(8)
              .focused($isTextFieldFocused)
              .onSubmit { sendMessage() }
              .disabled(viewModel.thinking)
              .task { isTextFieldFocused = true }

            Button(action: {
              sendMessage()
            }) {
              Image(systemName: "paperplane.fill")
                .font(.system(size: 16))
            }
            .buttonStyle(.borderless)
            .disabled(viewModel.thinking)
          }
          .padding()
          .background(
            RoundedRectangle(cornerRadius: 10)
              .fill(Color(NSColor.windowBackgroundColor))
              .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: -1)
          )
        }
      } else {
        Text("No chat selected")
          .foregroundStyle(.secondary)
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

      if let proxy = scrollProxy, let firstMessageId = viewModel.selectedThread?.messages.first?.id {
        withAnimation {
          proxy.scrollTo(firstMessageId, anchor: .top)
        }
      }
    }
    userMessage = ""
  }

  private func scrollToBottom(proxy: ScrollViewProxy) {
    withAnimation {
      proxy.scrollTo("bottom", anchor: .bottom)
    }
  }
}
