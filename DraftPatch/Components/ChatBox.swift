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
  @Binding var isTextFieldFocused: Bool

  let thinking: Bool
  let onSubmit: () -> Void
  let onCancel: () -> Void
  let draftWithLastApp: () -> Void

  @State private var isShowingPopover = false
  @State private var selectedText: String?
  @State private var lineNumbers: (start: Int, end: Int)?
  @State private var fileName: String?
  @State private var textEditorHeight: CGFloat = 15

  var draftingText: String {
    guard let app = selectedDraftApp else { return "" }
    let filePart = fileName ?? ""

    let linePart: String
    if let lineNumbers = lineNumbers {
      linePart =
        lineNumbers.start == lineNumbers.end
        ? " (\(lineNumbers.start))"
        : " (\(lineNumbers.start)-\(lineNumbers.end))"
    } else {
      linePart = ""
    }

    var parts = [String]()
    if !filePart.isEmpty {
      parts.append(filePart)
    }
    if !linePart.isEmpty {
      parts.append(linePart)
    }

    let formattedParts = parts.joined()
    return "Drafting with \(app.name)\(formattedParts.isEmpty ? "" : " • \(formattedParts)")"
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

      ChatBoxEditor(
        userMessage: $userMessage,
        isTextFieldFocused: $isTextFieldFocused,
        thinking: thinking,
        onSubmit: onSubmit,
        updateSelectedTextDetails: updateSelectedTextDetails
      )

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
        .accessibilityLabel("Open Drafting Options")
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

        Button(action: thinking ? onCancel : onSubmit) {
          Image(systemName: thinking ? "stop.circle.fill" : "arrowshape.up.circle.fill")
            .font(.title)
            .foregroundStyle(thinking ? Color.red : Color.accentColor)
        }
        .accessibilityLabel(thinking ? "Stop" : "Send")
        .buttonStyle(.borderless)
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
