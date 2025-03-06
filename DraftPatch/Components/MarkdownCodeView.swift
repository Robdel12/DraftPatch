//
//  MarkdownCodeView.swift
//  DraftPatch
//
//  Created by Robert DeLuca on 3/4/25.
//

import AppKit
import Highlightr
import MarkdownUI
import SwiftUI

struct MarkdownCodeView: View {
  let text: String

  var body: some View {
    Markdown(text)
      .markdownBlockStyle(\.codeBlock) { configuration in
        SyntaxHighlightedCodeBlock(code: configuration.content, language: configuration.language)
      }
  }
}

struct SyntaxHighlightedCodeBlock: View {
  let code: String
  let language: String?

  @State private var highlightedText: AttributedString = AttributedString("")
  @State private var showCopyConfirmation = false

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack {
        Text(language ?? "Code")
          .font(.system(size: 12, weight: .medium, design: .monospaced))
          .foregroundColor(.white)

        Spacer()

        Button(action: copyToClipboard) {
          HStack(spacing: 4) {
            Image(systemName: "doc.on.doc")
            Text("Copy")
          }
          .foregroundColor(.white)
          .font(.system(size: 12, weight: .medium, design: .monospaced))
        }
        .buttonStyle(BorderlessButtonStyle())
      }
      .padding(10)

      Divider()

      ScrollView(.horizontal) {
        Text(highlightedText)
          .padding(10)
          .font(.system(.body, design: .monospaced))
      }
    }
    .background(Color(red: 40 / 255.0, green: 44 / 255.0, blue: 52 / 255.0))
    .cornerRadius(8)
    .padding(.vertical)
    .onAppear(perform: highlightCode)
    .overlay(
      showCopyConfirmation
        ? Text("Copied!").foregroundColor(.white).padding(8).background(Color.black.opacity(0.7))
          .cornerRadius(5)
          .transition(.opacity)
          .animation(.easeInOut(duration: 0.5), value: showCopyConfirmation)
        : nil,
      alignment: .topTrailing
    )
  }

  private func highlightCode() {
    guard let highlightr = Highlightr() else {
      highlightedText = AttributedString(code)
      return
    }

    highlightr.setTheme(to: "atom-one-dark")

    let nsAttributedString =
      highlightr.highlight(code, as: language ?? "swift") ?? NSAttributedString(string: code)

    highlightedText = AttributedString(nsAttributedString)
  }

  private func copyToClipboard() {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(code, forType: .string)

    showCopyConfirmation = true
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
      showCopyConfirmation = false
    }
  }
}
