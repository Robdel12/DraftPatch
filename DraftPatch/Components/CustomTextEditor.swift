//
//  CustomTextEditor.swift
//  DraftPatch
//
//  Created by Robert DeLuca on 3/13/25.
//

import AppKit
import SwiftUI

struct CustomTextEditor: NSViewRepresentable {
  @Binding var text: String
  @Binding var isFocused: Bool

  var isEditable: Bool = true
  var thinking: Bool = false

  class Coordinator: NSObject, NSTextViewDelegate {
    var parent: CustomTextEditor

    init(_ parent: CustomTextEditor) {
      self.parent = parent
    }

    func textDidChange(_ notification: Notification) {
      if let textView = notification.object as? NSTextView {
        DispatchQueue.main.async {
          self.parent.text = textView.string
        }
      }
    }
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(self)
  }

  func makeNSView(context: Context) -> NSScrollView {
    let scrollView = NSScrollView()
    scrollView.hasVerticalScroller = true
    scrollView.autohidesScrollers = true
    scrollView.hasHorizontalScroller = false
    scrollView.drawsBackground = false
    scrollView.scrollerStyle = .overlay

    let textView = NSTextView()
    textView.delegate = context.coordinator
    textView.isEditable = isEditable
    textView.font = NSFont.systemFont(ofSize: 14)
    textView.backgroundColor = .clear
    textView.drawsBackground = false
    textView.isRichText = false
    textView.allowsUndo = true
    textView.isHorizontallyResizable = false
    textView.autoresizingMask = [.width, .height]
    textView.setAccessibilityIdentifier("Chatbox")
    textView.setAccessibilityLabel(thinking ? "Sending..." : "Draft a message")

    scrollView.documentView = textView
    return scrollView
  }

  func updateNSView(_ nsView: NSScrollView, context: Context) {
    if let textView = nsView.documentView as? NSTextView {
      if textView.string != text {
        textView.string = text
      }

      if isFocused && nsView.window?.firstResponder != textView {
        DispatchQueue.main.async {
          nsView.window?.makeFirstResponder(textView)
        }
      } else if !isFocused && nsView.window?.firstResponder == textView {
        DispatchQueue.main.async {
          nsView.window?.makeFirstResponder(nil)
        }
      }
    }
  }
}
