//
//  ChatView.swift
//  DraftPatch
//
//  Created by Robert DeLuca on 3/6/25.
//

import SwiftUI

struct ChatView: View {
  @EnvironmentObject var viewModel: DraftPatchViewModel
  @State private var userMessage = ""
  @State private var scrollViewProxy: ScrollViewProxy?
  @State private var currentViewportHeight: CGFloat = 0
  @State private var sentMessage: Bool = false

  private var sortedMessages: [ChatMessage] {
    viewModel.selectedThread?.messages.sorted { $0.timestamp < $1.timestamp } ?? []
  }

  @ViewBuilder
  private var noLLMConfiguredView: some View {
    VStack(spacing: 16) {
      Image(systemName: "gear")
        .resizable()
        .scaledToFit()
        .frame(width: 80, height: 80)
        .foregroundStyle(.secondary)
      Text("LLM Not Configured")
        .font(.title2)
        .bold()
      Text("Please configure an LLM to start using DraftPatch.")
        .multilineTextAlignment(.center)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 24)
      Button(action: {
        viewModel.showSettings.toggle()
      }) {
        HStack(spacing: 4) {
          Text("Enable an LLM provider")
          Image(systemName: "arrowshape.right.fill")
        }
      }
      .buttonStyle(.borderedProminent)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(.black.opacity(0.1))
  }

  @ViewBuilder
  private var noThreadsView: some View {
    VStack(spacing: 16) {
      Image(systemName: "flag.checkered")
        .resizable()
        .scaledToFit()
        .frame(width: 80, height: 80)
        .foregroundStyle(.secondary)
      Text("No Threads Available")
        .font(.title2)
        .bold()
      Text("Create a new thread to start drafting!")
        .multilineTextAlignment(.center)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 24)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(.black.opacity(0.1))
  }

  @ViewBuilder
  private var noChatSelectedView: some View {
    VStack(spacing: 16) {
      Image(systemName: "questionmark")
        .resizable()
        .scaledToFit()
        .frame(width: 80, height: 80)
        .foregroundStyle(.secondary)
      Text("No Chat Selected")
        .font(.title2)
        .bold()
      Text("Please select a chat from the list or create a new one.")
        .multilineTextAlignment(.center)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 24)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(.black.opacity(0.1))
  }

  private var chatView: some View {
    // Force unwrapping is safe here because this view is only used when a thread is selected
    let thread = viewModel.selectedThread!
    return VStack {
      VStack(spacing: 0) {
        if thread.messages.isEmpty {
          Text("No messages yet")
            .foregroundColor(.gray).opacity(0.01)
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }

        GeometryReader { geometry in
          Color.clear
            .onAppear {
              currentViewportHeight = geometry.size.height
            }
            .onChange(of: geometry.size.height) { _, newHeight in
              currentViewportHeight = newHeight
            }
          ScrollViewReader { scrollProxy in
            ScrollView {
              VStack(spacing: 0) {
                VStack(spacing: 8) {
                  ForEach(sortedMessages, id: \.id) { msg in
                    ChatMessageRow(message: msg)
                      .id(msg.id)
                      .environmentObject(viewModel)
                      .frame(maxWidth: .infinity, alignment: .leading)
                  }

                  if viewModel.isAwaitingResponse {
                    LoadingAnimationView()
                      .padding(.vertical, 8)
                  }

                  if sentMessage && (sortedMessages.filter { $0.role == .user }.count > 1) {
                    Spacer(minLength: currentViewportHeight - 150)
                      .id("bottomSpacer")
                      .accessibilityIdentifier("dynamicSpacer")
                  }

                  Color.clear.frame(height: 1)
                    .id("bottomAnchor")
                }
                .padding()
                .frame(maxWidth: 960)
              }
              .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .defaultScrollAnchor(.bottom)
            .onAppear {
              scrollViewProxy = scrollProxy
              sentMessage = false

              DispatchQueue.main.async {
                scrollProxy.scrollTo(sentMessage ? "bottomSpacer" : "bottomAnchor", anchor: .bottom)
              }
            }
            .onChange(of: viewModel.lastUserMessageID) { _, newID in
              guard let newID else { return }

              DispatchQueue.main.async {
                withAnimation(.smooth) {
                  scrollViewProxy?.scrollTo(newID, anchor: .top)
                }
              }
            }
          }
        }
        .frame(maxHeight: .infinity)

        if let error = viewModel.errorMessage {
          Text(error)
            .foregroundColor(.red)
            .padding(.vertical)
            .onAppear {
              DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                viewModel.errorMessage = nil
              }
            }
        }

        ChatBoxView(
          userMessage: $userMessage,
          selectedDraftApp: $viewModel.selectedDraftApp,
          isTextFieldFocused: $viewModel.chatBoxFocused,
          thinking: viewModel.thinking,
          onSubmit: sendMessage,
          onCancel: {
            viewModel.cancelStreamingMessage()
          },
          draftWithLastApp: viewModel.toggleDraftWithLastApp
        )
        .padding(.horizontal)
        .frame(maxWidth: 960)
      }
      .id(thread.id)
    }
    .padding(.bottom, 12)
    .background(.black.opacity(0.2))
  }

  var body: some View {
    if viewModel.availableModels.isEmpty {
      noLLMConfiguredView
    } else if viewModel.chatThreads.isEmpty && viewModel.selectedThread == nil {
      noThreadsView
    } else if viewModel.selectedThread == nil {
      noChatSelectedView
    } else {
      chatView
    }
  }

  private func sendMessage() {
    let textToSend = userMessage.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !textToSend.isEmpty else { return }

    sentMessage = true

    Task {
      await viewModel.sendMessage(textToSend)
    }

    userMessage = ""
  }
}
