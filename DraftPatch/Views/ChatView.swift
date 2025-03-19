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

  @State private var recentUserMessageId: String? = nil
  @State private var dynamicSpacerHeight: CGFloat? = nil
  @State private var scrollViewProxy: ScrollViewProxy?

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
            ScrollViewReader { scrollProxy in
              ScrollView {
                VStack(spacing: 0) {
                  VStack(spacing: 8) {
                    ForEach(thread.messages.sorted(by: { $0.timestamp < $1.timestamp }), id: \.id) { msg in
                      ChatMessageRow(message: msg)
                        .id(msg.id)
                        .environmentObject(viewModel)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                          GeometryReader { msgGeometry in
                            Color.clear
                              .onAppear {
                                if msg.role == .user, msg.id.uuidString == recentUserMessageId {
                                  DispatchQueue.main.async {
                                    let messageHeight = msgGeometry.size.height
                                    let availableHeight = geometry.size.height
                                    let calculatedSpacerHeight = max(availableHeight - messageHeight - 100, 0)

                                    withAnimation {
                                      dynamicSpacerHeight = calculatedSpacerHeight
                                    }
                                  }
                                }
                              }
                          }
                        )
                    }

                    if let height = dynamicSpacerHeight {
                      Spacer(minLength: height)
                        .accessibilityIdentifier("dynamicSpacer")
                        .id("dynamicSpacer")
                    }

                    Color.clear.frame(height: 1)
                      .id("bottomAnchor")
                  }
                  .padding()
                  .frame(maxWidth: 960)
                }
                .frame(maxWidth: .infinity, minHeight: geometry.size.height)
              }
              .onChange(of: viewModel.thinking) { oldValue, newValue in
                if newValue == true && oldValue == false {
                  withAnimation {
                    scrollProxy.scrollTo("bottomAnchor", anchor: .bottom)
                  }
                }
              }
              .onChange(of: viewModel.selectedThread) {
                recentUserMessageId = nil
                dynamicSpacerHeight = nil

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                  withAnimation {
                    scrollProxy.scrollTo("bottomAnchor", anchor: .bottom)
                  }
                }
              }
              .onAppear {
                scrollViewProxy = scrollProxy
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                  withAnimation {
                    scrollProxy.scrollTo("bottomAnchor", anchor: .bottom)
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
          .keyboardShortcut(KeyEquivalent.upArrow, modifiers: .command)

          Button {
            viewModel.selectPreviousThread()
          } label: {
            Text("Previous thread")
          }
          .opacity(0)
          .keyboardShortcut(KeyEquivalent.downArrow, modifiers: .command)

          ChatBoxView(
            userMessage: $userMessage,
            selectedDraftApp: $viewModel.selectedDraftApp,
            isTextFieldFocused: $viewModel.chatBoxFocused,
            thinking: viewModel.thinking,
            onSubmit: sendMessage,
            onCancel: {
              viewModel.cancelStreamingMessage()

              withAnimation {
                dynamicSpacerHeight = nil
              }
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

      if let lastUserMessage = viewModel.selectedThread?.messages.last(where: { $0.role == .user }) {
        recentUserMessageId = lastUserMessage.id.uuidString

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
          withAnimation {
            scrollViewProxy?.scrollTo(lastUserMessage.id, anchor: .top)
          }
        }
      }
    }
    userMessage = ""
  }
}
