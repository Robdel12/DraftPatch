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
  @FocusState.Binding var isTextFieldFocused: Bool

  let thinking: Bool
  let onSubmit: () -> Void

  @State private var isShowingPopover = false

  var body: some View {
    VStack(spacing: 16) {
      if let app = selectedDraftApp {
        VStack(alignment: .leading, spacing: 0) {
          HStack(spacing: 8) {
            Image(app.name)
              .resizable()
              .scaledToFit()
              .frame(width: 16, height: 16)

            Text("Drafting with \(app.name)")

            Spacer()

            Button("Stop", action: { selectedDraftApp = nil })
              .buttonStyle(PlainButtonStyle())
              .padding(6)
              .background(Color.black.opacity(0.2))
              .foregroundColor(.white)
              .cornerRadius(8)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        }
      }

      TextField(thinking ? "Sending..." : "Draft a message", text: $userMessage, axis: .vertical)
        .multilineTextAlignment(.leading)
        .font(.system(size: 14, weight: .regular, design: .rounded))
        .textFieldStyle(PlainTextFieldStyle())
        .focused($isTextFieldFocused)
        .disabled(thinking)
        .onAppear {
          DispatchQueue.main.async {
            isTextFieldFocused = true
          }
        }
        .onKeyPress { keyPress in
          if keyPress.modifiers == .shift
            && keyPress.key == .return
          {
            userMessage += "\n"
            return .handled
          } else if keyPress.modifiers.isEmpty && keyPress.key == .return {
            onSubmit()
            return .handled
          } else {
            return .ignored
          }
        }

      Divider()

      HStack {
        Button(action: {
          isShowingPopover.toggle()
        }) {
          Image(systemName: "car.side.air.fresh")
            .font(.title2)
            .foregroundStyle(selectedDraftApp != nil ? .blue : .gray)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isShowingPopover, arrowEdge: .top) {
          DraftingPopover(selectedDraftApp: $selectedDraftApp, isShowingPopover: $isShowingPopover)
        }

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
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding()
    .background(Color(.secondarySystemFill))
    .cornerRadius(8)
  }
}
