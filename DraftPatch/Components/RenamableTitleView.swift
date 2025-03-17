//
//  RenamableTitleView.swift
//  DraftPatch
//
//  Created by Robert DeLuca on 3/3/25.
//

import SwiftUI

struct RenamableTitleView: View {
  @ObservedObject var thread: ChatThread
  @State private var isRenaming = false
  @State private var localTitle: String
  @FocusState private var focused: Bool

  init(thread: ChatThread) {
    self.thread = thread
    self._localTitle = State(initialValue: thread.title)
  }

  var body: some View {
    Group {
      if isRenaming {
        TextField(
          "", text: $localTitle,
          onCommit: {
            thread.title = localTitle
            isRenaming = false
          }
        )
        .accessibilityIdentifier("renameThreadTextField")
        .textFieldStyle(.roundedBorder)
        .frame(maxWidth: 200)
        .focused($focused)
        .onKeyPress { key in
          if key.characters == "\u{1B}" {
            localTitle = thread.title
            focused = false
            isRenaming = false
            return .handled
          }
          return .ignored
        }
        .task {
          DispatchQueue.main.async {
            focused = true
          }
        }
      } else {
        Text(thread.title)
          .font(.title2)
          .fontWeight(.bold)
          .frame(maxWidth: 300)
          .onTapGesture(count: 2) {
            isRenaming = true
          }
      }
    }
  }
}
