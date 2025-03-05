//
//  ChatBoxView.swift
//  DraftPatch
//
//  Created by Robert DeLuca on 3/5/25.
//

import SwiftUI

struct ChatBoxView: View {
  @Binding var userMessage: String
  @Binding var selectedDraftApp: DraftApp?
  let thinking: Bool
  let onSubmit: () -> Void

  @FocusState private var isTextFieldFocused: Bool

  var body: some View {
    VStack(spacing: 16) {
      let placeholder = thinking ? "Sending..." : "Draft a message"

      TextField(placeholder, text: $userMessage, axis: .vertical)
        .multilineTextAlignment(.leading)
        .textFieldStyle(PlainTextFieldStyle())
        .focused($isTextFieldFocused)
        .disabled(thinking)
        .font(.system(size: 14, weight: .regular, design: .rounded))

      Divider()

      HStack {
        Picker("Draft with", selection: $selectedDraftApp) {
          Text("None").tag(nil as DraftApp?)

          ForEach(DraftApp.allCases) { app in
            Text(app.rawValue).tag(app)
          }
        }
        .pickerStyle(.menu)
        .frame(maxWidth: 420)

        Spacer()

        Button(action: onSubmit) {
          Image(systemName: "arrowshape.up.circle.fill")
            .font(.title)
            .foregroundStyle(thinking ? Color.gray : Color.accentColor)
        }
        .buttonStyle(.borderless)
        .disabled(thinking)
      }
    }
    .padding()
    .background(Color(.secondarySystemFill))
    .cornerRadius(8)
    .frame(maxWidth: 960)
  }
}

// MARK: - Preview
struct ChatBoxView_Previews: PreviewProvider {
  struct PreviewWrapper: View {
    @State private var userMessage = "eweweewe"
    @State private var selectedDraftApp: DraftApp? = nil

    var body: some View {
      ChatBoxView(
        userMessage: $userMessage,
        selectedDraftApp: $selectedDraftApp,
        thinking: false
      ) {
        print("Submit tapped")
      }
      .padding()
      .previewLayout(.sizeThatFits)
    }
  }

  static var previews: some View {
    PreviewWrapper()
  }
}
