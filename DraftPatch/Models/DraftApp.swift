//
//  DraftApp.swift
//  DraftPatch
//
//  Created by Robert DeLuca on 3/7/25.
//

enum DraftApp: String, CaseIterable, Codable, Identifiable, Hashable {
  case xcode = "Xcode"
  case emacs = "Emacs"

  var id: String {
    switch self {
    case .xcode:
      return "com.apple.dt.Xcode"
    case .emacs:
      return "org.gnu.Emacs"
    }
  }

  var name: String { self.rawValue }
}
