//
//  Settings.swift
//  DraftPatch
//
//  Created by Robert DeLuca on 3/7/25.
//

import Foundation
import SwiftData

@Model
class Settings {
  @Attribute(.unique) var id: UUID?

  var isOpenAIEnabled: Bool
  var openAIAPIKeyIdentifier: String?

  init(isOpenAIEnabled: Bool = false, openAIAPIKeyIdentifier: String? = nil) {
    self.isOpenAIEnabled = isOpenAIEnabled
    self.openAIAPIKeyIdentifier = openAIAPIKeyIdentifier
  }
}
