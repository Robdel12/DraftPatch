//
//  HighlightrService.swift
//  DraftPatch
//
//  Created by Robert DeLuca on 3/12/25.
//

import Foundation
import Highlightr

final class HighlightrService {
  static let shared = HighlightrService()
  let highlightr: Highlightr

  private init() {
    guard let instance = Highlightr() else {
      fatalError("Highlightr could not be initialized")
    }
    self.highlightr = instance
    self.highlightr.setTheme(to: "atom-one-dark")
  }

  func highlight(code: String, language: String?) -> NSAttributedString {
    return highlightr.highlight(code, as: language ?? "swift") ?? NSAttributedString(string: code)
  }
}

