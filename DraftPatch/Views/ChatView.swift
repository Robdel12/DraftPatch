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

  var body: some View {
    if let thread = viewModel.selectedThread {
      VStack {
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
      .background(.black.opacity(0.1))
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
