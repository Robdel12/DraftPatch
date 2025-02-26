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
                .background(thread == viewModel.selectedThread ? Color.accentColor.opacity(0.2) : Color.clear)
                .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
          }
        }
      }
      .toolbar {
        Button("New Chat") {
          viewModel.createNewThread(title: "New Conversation")
        }
        .keyboardShortcut("n", modifiers: .command)
      }
    } detail: {
      if let thread = viewModel.selectedThread {
        VStack {
          HStack {
            Text(thread.title)
              .font(.title2)
            Spacer()

            Picker(
              "Model",
              selection: Binding(
                get: { thread.modelName },
                set: { newModel in
                  viewModel.setModelForCurrentThread(newModel)
                }
              )
            ) {
              ForEach(viewModel.availableModels, id: \.self) { model in
                Text(model)
              }
            }
            .pickerStyle(MenuPickerStyle())
          }
          .padding([.top, .horizontal])

          Divider()
          ScrollViewReader { proxy in
            ScrollView(.vertical) {
              VStack(spacing: 8) {
                ForEach(thread.messages.sorted(by: { $0.timestamp < $1.timestamp }), id: \.id) { msg in
                  ChatMessageRow(message: msg)
                    .id(msg.id)
                }
                Rectangle()
                  .fill(Color.clear)
                  .frame(width: 1, height: 1)
                  .id("bottom")
              }
              .padding()
            }
            .onAppear {
              scrollProxy = proxy
              scrollToBottom(proxy: proxy)
            }
            .onChange(of: thread.messages) { _ in
              scrollToBottom(proxy: proxy)
            }
            // New onChange handler to scroll when new partial text arrives
            .onChange(of: viewModel.streamingUpdate) { _ in
              scrollToBottom(proxy: proxy)
            }
          }
          Divider()

          HStack {
            TextField("Send a message...", text: $userMessage, axis: .vertical)
              .lineLimit(4, reservesSpace: true)
              .cornerRadius(8)
              .focused($isTextFieldFocused)
              .onSubmit {
                sendMessage()
              }
              .disabled(viewModel.thinking)  // Disable input while streaming
              .task {
                isTextFieldFocused = true
              }

            Button {
              sendMessage()
            } label: {
              Image(systemName: "paperplane.fill")
            }
            .buttonStyle(BorderlessButtonStyle())
            .disabled(viewModel.thinking)  // Disable send button while streaming
          }
          .padding()
        }
      } else {
        Text("No chat selected")
          .foregroundStyle(.secondary)
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
