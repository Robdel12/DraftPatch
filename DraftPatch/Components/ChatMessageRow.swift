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
  case userSelectedCode(String)
}

private func parseMessage(_ text: String) -> [MessageSegment] {
  var segments: [MessageSegment] = []
  var remainingText = text

  while true {
    // Find the next occurrence of either tag
    let thinkRange = remainingText.range(of: "<think>")
    let userCodeRange = remainingText.range(of: "<userSelectedCode>")

    // Determine which tag comes first
    var startRange: Range<String.Index>?
    var tagMatch: String = ""
    if let thinkRange = thinkRange, let userCodeRange = userCodeRange {
      if thinkRange.lowerBound < userCodeRange.lowerBound {
        startRange = thinkRange
        tagMatch = "<think>"
      } else {
        startRange = userCodeRange
        tagMatch = "<userSelectedCode>"
      }
    } else if let thinkRange = thinkRange {
      startRange = thinkRange
      tagMatch = "<think>"
    } else if let userCodeRange = userCodeRange {
      startRange = userCodeRange
      tagMatch = "<userSelectedCode>"
    } else {
      // No more tags found
      break
    }

    // Append any text before the tag
    let beforeTag = String(remainingText[..<startRange!.lowerBound])
    if !beforeTag.isEmpty {
      segments.append(.normal(beforeTag))
    }

    // Determine the corresponding closing tag
    let closingTag = tagMatch == "<think>" ? "</think>" : "</userSelectedCode>"

    // Move past the opening tag
    let afterOpenTag = remainingText[startRange!.upperBound...]

    if let endRange = afterOpenTag.range(of: closingTag) {
      let content = String(afterOpenTag[..<endRange.lowerBound])
      segments.append(tagMatch == "<think>" ? .think(content) : .userSelectedCode(content))
      remainingText = String(afterOpenTag[endRange.upperBound...])
    } else {
      // If no closing tag is found, treat the rest as content
      let content = String(afterOpenTag)
      segments.append(tagMatch == "<think>" ? .think(content) : .userSelectedCode(content))
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
        MarkdownCodeView(text: text)

        Divider()
          .padding(.bottom)
      },
      label: {
        Button(action: {
          isExpanded.toggle()
        }) {
          HStack {
            Image(systemName: "brain.head.profile")
            Text(isStreaming ? "Reasoning..." : "Reasoned")
              .font(.system(size: 14))
          }
          .padding(8)
          .background(Color.blue.opacity(0.1))
          .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
      }
    )
    .accentColor(.blue)
    .padding(.vertical, 4)
  }
}

struct CollapsibleUserSelectedCodeView: View {
  let text: String

  @State private var isExpanded = false

  var body: some View {
    DisclosureGroup(
      isExpanded: $isExpanded,
      content: {
        MarkdownCodeView(text: text)

        Divider()
          .padding(.bottom)
      },
      label: {
        Button(action: {
          isExpanded.toggle()
        }) {
          HStack {
            Image(systemName: "chevron.left.slash.chevron.right")
            Text("Drafted text")
              .font(.subheadline)
          }
          .padding(8)
          .background(Color.blue.opacity(0.1))
          .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
      }
    )
    .accentColor(.blue)
    .padding(.vertical, 4)
  }
}

struct ParsedMessageView: View {
  let text: String
  let isStreaming: Bool
  let role: Role

  var body: some View {
    let segments = parseMessage(text)
    VStack(alignment: .leading, spacing: 4) {
      ForEach(segments.indices, id: \.self) { index in
        switch segments[index] {
        case .normal(let content):
          MarkdownCodeView(text: content)
        case .think(let content):
          CollapsibleThinkView(text: content, isStreaming: isStreaming)
        case .userSelectedCode(let content):
          CollapsibleUserSelectedCodeView(text: content)
        }
      }
    }
  }
}

struct ChatMessageRow: View {
  let message: ChatMessage

  @EnvironmentObject var viewModel: DraftPatchViewModel

  var body: some View {
    messageBubble(message)
  }

  @ViewBuilder
  private func messageBubble(_ msg: ChatMessage) -> some View {
    switch msg.role {
    case .user:
      Group {
        HStack {
          Spacer(minLength: 150)

          ParsedMessageView(text: msg.text, isStreaming: msg.streaming, role: msg.role)
            .padding()
            .background(.gray.opacity(0.1))
            .cornerRadius(8)
            .textSelection(.enabled)
        }
      }

    case .assistant, .system:
      HStack {
        ParsedMessageView(text: msg.text, isStreaming: msg.streaming, role: msg.role)
          .padding()
          .textSelection(.enabled)
      }
    }
  }
}
