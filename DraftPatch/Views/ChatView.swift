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

  @FocusState.Binding var isTextFieldFocused: Bool

  var body: some View {
    if let thread = viewModel.selectedThread {
      VStack {
        VStack(spacing: 0) {
          ScrollView {
            VStack(spacing: 0) {
              LazyVStack(spacing: 8) {
                ForEach(thread.messages.sorted(by: { $0.timestamp < $1.timestamp }), id: \.id) { msg in
                  ChatMessageRow(message: msg)
                    .id(msg.id)
                    .environmentObject(viewModel)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
              }
              .padding()
              .frame(maxWidth: 960)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
          }
          .defaultScrollAnchor(.bottom)

          ChatBoxView(
            userMessage: $userMessage,
            selectedDraftApp: $viewModel.selectedDraftApp,
            isTextFieldFocused: $isTextFieldFocused,
            thinking: viewModel.thinking,
            onSubmit: sendMessage
          )
          .padding(.horizontal)
          .frame(maxWidth: 960)
        }
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
  }
}
