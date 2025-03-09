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

  var defaultModel: String = ""

  var isOpenAIEnabled: Bool = false
  var openAIAPIKeyIdentifier: String?

  var isGeminiEnabled: Bool = false
  var geminiAPIKeyIdentifier: String?

  init(
    isOpenAIEnabled: Bool = false, openAIAPIKeyIdentifier: String? = nil,
    isGeminiEnabled: Bool = false, geminiAPIKeyIdentifier: String? = nil
  ) {
    self.isOpenAIEnabled = isOpenAIEnabled
    self.openAIAPIKeyIdentifier = openAIAPIKeyIdentifier
    self.isGeminiEnabled = isGeminiEnabled
    self.geminiAPIKeyIdentifier = geminiAPIKeyIdentifier
  }
}
