//
//  ChatBoxEditor.swift
//  DraftPatch
//
//  Created by Robert DeLuca on 3/13/25.
//

import Combine
import SwiftUI

struct ChatBoxEditor: View {
  @Binding var userMessage: String
  @FocusState.Binding var isTextFieldFocused: Bool
  @State private var textEditorHeight: CGFloat = 15

  let thinking: Bool
  let onSubmit: () -> Void
  let updateSelectedTextDetails: () -> Void

  var body: some View {
    ZStack(alignment: .topLeading) {
      if userMessage.isEmpty {
        Text(thinking ? "Sending..." : "Draft a message")
          .font(.system(size: 14, weight: .regular, design: .rounded))
          .foregroundColor(.gray)
          .padding(0)
          .padding(.leading, 5)
          .frame(maxWidth: .infinity, alignment: .leading)
      }

      Text(userMessage.isEmpty ? " " : userMessage)
        .font(.system(size: 14, weight: .regular, design: .rounded))
        .padding(8)
        .frame(maxWidth: .infinity)
        .background(
          GeometryReader { geometry in
            Color.clear
              .onAppear { textEditorHeight = max(15, geometry.size.height + 16) }
              .onChange(of: userMessage) {
                textEditorHeight = max(15, geometry.size.height + 16)
              }
          }
        )
        .opacity(0)

      CustomTextEditor(text: $userMessage, isFocused: $isTextFieldFocused, thinking: thinking)
        .frame(minHeight: 15, maxHeight: textEditorHeight)
        .font(.system(size: 14, weight: .regular, design: .rounded))
        .disabled(thinking)
        .accessibilityLabel(thinking ? "Sending..." : "Draft a message")
        .onAppear {
          updateSelectedTextDetails()
          DispatchQueue.main.async {
            isTextFieldFocused = true
          }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) {
          _ in
          updateSelectedTextDetails()
        }
        .onKeyPress { keyPress in
          if keyPress.modifiers.isEmpty && keyPress.key == .return {
            onSubmit()
            return .handled
          } else {
            return .ignored
          }
        }
    }
  }
}
