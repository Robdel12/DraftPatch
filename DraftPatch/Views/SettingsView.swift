//
//  SettingsView.swift
//  DraftPatch
//
//  Created by Robert DeLuca on 3/6/25.
//

import SwiftData
import SwiftUI

struct SettingsView: View {
  @Environment(\.modelContext) private var modelContext
  @Query private var settings: [Settings]

  @State private var isOpenAIEnabled: Bool = false
  @State private var openAIApiKey: String = ""

  @State private var isGeminiEnabled: Bool = false
  @State private var geminiApiKey: String = ""

  private let openAIApiKeyIdentifier = "openai_api_key"
  private let geminiApiKeyIdentifier = "gemini_api_key"

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      Text("Settings")
        .font(.largeTitle)
        .bold()

      Divider()

      Text("LLM Settings")
        .font(.title3)
        .bold()

      Toggle("Enable OpenAI", isOn: $isOpenAIEnabled)
        .onChange(of: isOpenAIEnabled) {
          updateSettings()
        }

      if isOpenAIEnabled {
        SecureField("Enter OpenAI API Key", text: $openAIApiKey)
          .textFieldStyle(RoundedBorderTextFieldStyle())
          .padding(.vertical, 5)
          .frame(maxWidth: 420)

        Button("Save OpenAI API Key") {
          KeychainHelper.shared.save(
            openAIApiKey.trimmingCharacters(in: .whitespacesAndNewlines), for: openAIApiKeyIdentifier)
          updateSettings()
        }
        .buttonStyle(.bordered)
      }

      Toggle("Enable Gemini", isOn: $isGeminiEnabled)
        .onChange(of: isGeminiEnabled) {
          updateSettings()
        }

      if isGeminiEnabled {
        SecureField("Enter Gemini API Key", text: $geminiApiKey)
          .textFieldStyle(RoundedBorderTextFieldStyle())
          .padding(.vertical, 5)
          .frame(maxWidth: 420)

        Button("Save Gemini API Key") {
          KeychainHelper.shared.save(
            geminiApiKey.trimmingCharacters(in: .whitespacesAndNewlines), for: geminiApiKeyIdentifier)
          updateSettings()
        }
        .buttonStyle(.bordered)
      }

      Spacer()
      HStack {
        Spacer()
        Text("Made with ❤️ and 🤔 by Robert DeLuca")
          .font(.footnote)
          .foregroundStyle(.white.opacity(0.3))
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .padding()
    .onAppear {
      loadSettings()
    }
  }

  private func loadSettings() {
    if let existingSettings = settings.first {
      isOpenAIEnabled = existingSettings.isOpenAIEnabled
      openAIApiKey = KeychainHelper.shared.load(for: openAIApiKeyIdentifier) ?? ""
      isGeminiEnabled = existingSettings.isGeminiEnabled
      geminiApiKey = KeychainHelper.shared.load(for: geminiApiKeyIdentifier) ?? ""
    } else {
      let newSettings = Settings(
        isOpenAIEnabled: false,
        openAIAPIKeyIdentifier: openAIApiKeyIdentifier,
        isGeminiEnabled: false,
        geminiAPIKeyIdentifier: geminiApiKeyIdentifier
      )
      modelContext.insert(newSettings)
    }
  }

  private func updateSettings() {
    if let existingSettings = settings.first {
      existingSettings.isOpenAIEnabled = isOpenAIEnabled
      existingSettings.openAIAPIKeyIdentifier = openAIApiKeyIdentifier
      existingSettings.isGeminiEnabled = isGeminiEnabled
      existingSettings.geminiAPIKeyIdentifier = geminiApiKeyIdentifier
    }
  }
}
