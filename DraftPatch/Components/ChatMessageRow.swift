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

private func parseMessage(_ text: String) -> [MessageSegment] {
  var segments: [MessageSegment] = []
  var remainingText = text

  while let startRange = remainingText.range(of: "<think>") {
    let beforeThink = String(remainingText[..<startRange.lowerBound])
    if !beforeThink.isEmpty {
      segments.append(.normal(beforeThink))
    }

    let afterOpenTag = remainingText[startRange.upperBound...]

    if let endRange = afterOpenTag.range(of: "</think>") {
      let thinkContent = String(afterOpenTag[..<endRange.lowerBound])
      segments.append(.think(thinkContent))
      remainingText = String(afterOpenTag[endRange.upperBound...])
    } else {
      let thinkContent = String(afterOpenTag)
      segments.append(.think(thinkContent))
      remainingText = ""
    }
  }

  if !remainingText.isEmpty {
    segments.append(.normal(remainingText))
  }

  return segments
}

struct CollapsibleThinkView: View {
  let text: String
  let isStreaming: Bool
  @State private var isExpanded = false

  var body: some View {
    DisclosureGroup(
      isExpanded: $isExpanded,
      content: {
        Markdown(text)
          .padding(.horizontal)
          .padding(.bottom)

        Divider()
          .padding(.bottom)
      },
      label: {
        HStack {
          Image(systemName: "brain.head.profile")
            .foregroundColor(.blue)
          Text(isStreaming ? "Reasoning..." : "Reasoned")
            .font(.subheadline)
            .foregroundColor(.primary)
        }
        .padding(8)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(8)
      }
    )
    .accentColor(.blue)
    .padding(.vertical, 4)
  }
}

struct ParsedMessageView: View {
  @EnvironmentObject var viewModel: ChatViewModel
  let text: String

  var body: some View {
    let segments = parseMessage(text)
    VStack(alignment: .leading, spacing: 4) {
      ForEach(0..<segments.count, id: \.self) { index in
        switch segments[index] {
        case .normal(let content):
          Markdown(content)
        case .think(let content):
          CollapsibleThinkView(text: content, isStreaming: viewModel.thinking)
        }
      }
    }
  }
}

struct ChatMessageRow: View {
  let message: ChatMessage
  @EnvironmentObject var viewModel: ChatViewModel

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
          .background(Color.blue.opacity(0.2))
          .cornerRadius(8)
          .environmentObject(viewModel)
      }
    case .assistant, .system:
      HStack {
        ParsedMessageView(text: msg.text)
          .padding()
          .background(Color.gray.opacity(0.2))
          .cornerRadius(8)
          .environmentObject(viewModel)
        Spacer()
      }
    }
  }
}
