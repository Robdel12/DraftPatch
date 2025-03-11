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
  let draftWithLastApp: () -> Void

  @State private var isShowingPopover = false
  @State private var selectedText: String?
  @State private var lineNumbers: (start: Int, end: Int)?
  @State private var fileName: String?

  var draftingText: String {
    guard let app = selectedDraftApp else { return "" }
    let filePart = fileName ?? "Unknown"

    let linePart: String
    if let lineNumbers = lineNumbers {
      linePart =
        lineNumbers.start == lineNumbers.end
        ? " (\(lineNumbers.start))"
        : " (\(lineNumbers.start)-\(lineNumbers.end))"
    } else {
      linePart = ""
    }

    return "Drafting with \(app.name) • \(filePart)\(linePart)"
  }

  var body: some View {
    VStack(spacing: 16) {
      if let app = selectedDraftApp {
        VStack(alignment: .leading, spacing: 0) {
          HStack(spacing: 8) {
            Image(app.name)
              .resizable()
              .scaledToFit()
              .frame(width: 16, height: 16)

            Text(draftingText)
              .lineLimit(1)
              .truncationMode(.tail)

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
          if keyPress.modifiers == .shift && keyPress.key == .return {
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
            .font(.title3)
            .foregroundStyle(selectedDraftApp != nil ? .blue : .gray)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isShowingPopover, arrowEdge: .top) {
          DraftingPopover(selectedDraftApp: $selectedDraftApp, isShowingPopover: $isShowingPopover)
        }

        Button(action: {
          draftWithLastApp()
        }) {
          EmptyView()
        }
        .keyboardShortcut("d", modifiers: .command)
        .accessibilityLabel("Draft with Last App")
        .accessibilityHint("Activates the draft with the last used app")
        .buttonStyle(.borderless)

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

  private func updateSelectedTextDetails() {
    guard let app = selectedDraftApp else { return }
    let (text, lines, file) = DraftingService.shared.getSelectedTextDetails(appIdentifier: app.id)
    selectedText = text
    lineNumbers = lines
    fileName = file
  }
}
