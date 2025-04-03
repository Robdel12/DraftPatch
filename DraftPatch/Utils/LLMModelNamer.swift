//
//  LLMModelNamer.swift
//  DraftPatch
//
//  Created by Robert DeLuca on 4/2/25.
//

import Foundation

struct LLMModelNamer {
  static func prettyPrint(_ modelName: String) -> String {
    if let match = matchClaude(modelName) {
      return match
    } else if let match = matchGemini(modelName) {
      return match
    } else if let match = matchOpenAI(modelName) {
      return match
    } else if let match = matchOllama(modelName) {
      return match
    } else {
      return modelName
    }
  }

  private static func matchClaude(_ name: String) -> String? {
    name.lowercased().contains("claude") ? prettyClaudeName(from: name) : nil
  }

  private static func matchGemini(_ name: String) -> String? {
    let lower = name.lowercased()
    if lower.contains("gemini") || lower.contains("bison") || lower.contains("gecko") {
      return prettyGeminiName(from: name)
    }
    return nil
  }

  private static func matchOpenAI(_ name: String) -> String? {
    let lower = name.lowercased()
    if lower.contains("gpt-") || lower.contains("text-embedding") || lower.contains("dall-e")
      || lower.contains("whisper") || lower.contains("tts-")
    {
      return prettyOpenAIName(from: name)
    }
    return nil
  }

  private static func matchOllama(_ name: String) -> String? {
    let lower = name.lowercased()
    if lower.contains("gemma") || lower.contains("qwen") || lower.contains("deepseek")
      || lower.contains("olmo")
    {
      return prettyOllamaName(from: name)
    }
    return nil
  }

  private static func prettyClaudeName(from name: String) -> String {
    // e.g., "claude-3-5-haiku-20241022" → "Claude 3.5 Haiku"
    let parts =
      name
      .replacingOccurrences(of: "claude-", with: "")
      .split(separator: "-")

    var version = ""
    var family = ""
    for part in parts {
      if part.contains(".") || part.allSatisfy(\.isNumber) {
        version += version.isEmpty ? part : ".\(part)"
      } else if part.count > 2 {
        family = part.capitalized
        break
      }
    }

    return "Claude \(version) \(family)"
  }

  private static func prettyGeminiName(from name: String) -> String {
    if name.contains("bison") {
      return name.contains("chat") ? "Chat Bison" : "Text Bison"
    }

    if name.contains("gecko") {
      return "Gecko Embedding"
    }

    if name.contains("embedding") {
      return "Gemini Embedding"
    }

    if name.contains("imagen") {
      return "Imagen"
    }

    // e.g., "gemini-1.5-flash-001" → "Gemini 1.5 Flash"
    let parts =
      name
      .replacingOccurrences(of: "gemini-", with: "")
      .split(separator: "-")

    var result = "Gemini"
    var versionAppended = false
    for part in parts {
      if part.contains(".") || part.allSatisfy(\.isNumber), !versionAppended {
        result += " \(part)"
        versionAppended = true
      } else if part != "exp" && !part.contains("preview") && !part.contains("exp")
        && !part.contains("thinking")
      {
        result += " \(part.capitalized)"
      }
    }

    return result
  }

  private static func prettyOllamaName(from name: String) -> String {
    let baseName =
      name
      .replacingOccurrences(of: "hf.co/", with: "")
      .replacingOccurrences(of: "_", with: " ")
      .replacingOccurrences(of: "-", with: " ")
      .replacingOccurrences(of: ":", with: " ")
      .components(separatedBy: "/")
      .last ?? name

    let words =
      baseName
      .split(separator: " ")
      .map { $0.capitalized }

    return words.joined(separator: " ")
  }

  private static func prettyOpenAIName(from name: String) -> String {
    let cleaned = name.replacingOccurrences(of: "-", with: " ")
    let words = cleaned.split(separator: " ").map { $0.capitalized }
    return words.joined(separator: " ")
  }
}
