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
                    ForEach(thread.messages.sorted(by: { $0.timestamp < $1.timestamp }), id: \.id) { msg in
                      ChatMessageRow(message: msg)
                        .id(msg.id)
                        .environmentObject(viewModel)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if sentMessage {
                      Spacer(minLength: currentViewportHeight - 200)
                        .id("bottomSpacer")
                    }

                    Color.clear.frame(height: 1)
                      .id("bottomAnchor")

                  }
                  .padding()
                  .frame(maxWidth: 960)
                }
                .frame(maxWidth: .infinity, minHeight: geometry.size.height)
              }
              .defaultScrollAnchor(.bottom)
              .onChange(of: viewModel.selectedThread?.messages) {
                if let thread = viewModel.selectedThread {
                  let sortedMessages = thread.messages.sorted(by: { $0.timestamp < $1.timestamp })

                  if let lastUserMessage = sortedMessages.last(where: { $0.role == .user }) {
                    DispatchQueue.main.async {
                      withAnimation {
                        scrollViewProxy?.scrollTo(lastUserMessage.id, anchor: .top)
                      }
                    }
                  }
                }
              }
              .onAppear {
                scrollViewProxy = scrollProxy

                DispatchQueue.main.async {
                  withAnimation {
                    if thread.messages.count > 0 {
                      scrollProxy.scrollTo("bottomSpacer", anchor: .bottom)
                    } else {
                      scrollProxy.scrollTo("bottomAnchor", anchor: .bottom)
                    }
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

          Button {
            viewModel.selectNextThread()
          } label: {
            Text("Next thread")
          }
          .opacity(0)
          .keyboardShortcut(KeyEquivalent.downArrow, modifiers: .command)

          Button {
            viewModel.selectPreviousThread()
          } label: {
            Text("Previous thread")
          }
          .opacity(0)
          .keyboardShortcut(KeyEquivalent.upArrow, modifiers: .command)

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

  private func sendMessage() {
    let textToSend = userMessage.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !textToSend.isEmpty else { return }

    Task {
      await viewModel.sendMessage(textToSend)
    }

    userMessage = ""
    sentMessage = true
  }
}
