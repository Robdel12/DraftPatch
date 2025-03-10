//
//  LLMConfig.swift
//  DraftPatch
//
//  Created by Robert DeLuca on 3/9/25.
//

protocol LLMConfig {
  var enabled: Bool { get set }
  var temperature: Double { get set }
  var maxTokens: Int { get set }
}
