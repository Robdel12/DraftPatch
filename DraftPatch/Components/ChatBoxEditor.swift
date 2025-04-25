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
  @Binding var isTextFieldFocused: Bool
  @State private var textEditorHeight: CGFloat = 8

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
        .font(.system(size: 15, weight: .regular, design: .rounded))
        .frame(maxWidth: .infinity)
        .background(
          GeometryReader { geometry in
            Color.clear
              .onAppear { textEditorHeight = max(15, geometry.size.height + 10) }
              .onChange(of: userMessage) {
                textEditorHeight = max(15, geometry.size.height + 12)
              }
          }
        )
        .opacity(0)

      CustomTextEditor(text: $userMessage, isFocused: $isTextFieldFocused, thinking: thinking)
        .frame(minHeight: 8, maxHeight: textEditorHeight)
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
