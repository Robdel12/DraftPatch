//
//  ChatMessageRow.swift
//  DraftPatch
//
//  Created by Robert DeLuca on 3/2/25.
//

import MarkdownUI
import SwiftUI

enum MessageSegment {
  case normal(String)
  case think(String)
}

struct ChatMessageRow: View {
  let message: ChatMessage

  var body: some View {
    messageBubble(message)
  }

  @ViewBuilder
  private func messageBubble(_ msg: ChatMessage) -> some View {
    switch msg.role {
    case .user:
      HStack {
        Spacer()
        ParsedMessageView(text: msg.text)
          .padding()
          .background(Color.gray.opacity(0.2))
          .cornerRadius(8)
      }
    case .assistant, .system:
      HStack {
        ParsedMessageView(text: msg.text)
          .padding()
          .background(Color.blue.opacity(0.2))
          .cornerRadius(8)
        Spacer()
      }
    }
  }
}

private func parseMessage(_ text: String) -> [MessageSegment] {
  var segments: [MessageSegment] = []
  var remainingText = text
  while let startRange = remainingText.range(of: "<think>"),
    let endRange = remainingText.range(of: "</think>")
  {
    let beforeThink = String(remainingText[..<startRange.lowerBound])
    if !beforeThink.isEmpty {
      segments.append(.normal(beforeThink))
    }
    let thinkContent = String(remainingText[startRange.upperBound..<endRange.lowerBound])
    segments.append(.think(thinkContent))
    remainingText = String(remainingText[endRange.upperBound...])
  }
  if !remainingText.isEmpty {
    segments.append(.normal(remainingText))
  }
  return segments
}

struct MarkdownText: View {
  let markdown: String

  var body: some View {
    Markdown(markdown)
  }
}

struct ParsedMessageView: View {
  let text: String

  var body: some View {
    let segments = parseMessage(text)
    VStack(alignment: .leading, spacing: 4) {
      ForEach(0..<segments.count, id: \.self) { index in
        switch segments[index] {
        case .normal(let content):
          MarkdownText(markdown: content)
        case .think(let content):
          CollapsibleThinkView(text: content)
        }
      }
    }
  }
}

struct CollapsibleThinkView: View {
  let text: String
  @State private var isExpanded = false

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      Button(action: {
        withAnimation {
          isExpanded.toggle()
        }
      }) {
        Text(isExpanded ? "Hide Thought" : "Show Thought")
          .font(.caption)
          .foregroundColor(.black)
      }
      if isExpanded {
        MarkdownText(markdown: text)
          .transition(.opacity)
      }
    }
  }
}
