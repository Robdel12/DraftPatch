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
  @EnvironmentObject private var viewModel: DraftPatchViewModel
  @Query private var settings: [Settings]

  @State private var selectedDefaultModel: ChatModel?

  @State private var isOpenAIEnabled: Bool = false
  @State private var openAIApiKey: String = ""

  @State private var isGeminiEnabled: Bool = false
  @State private var geminiApiKey: String = ""

  @State private var isAnthropicEnabled: Bool = false
  @State private var anthropicApiKey: String = ""

  private let openAIApiKeyIdentifier = "openai_api_key"
  private let geminiApiKeyIdentifier = "gemini_api_key"
  private let anthropicApiKeyIdentifier = "anthropic_api_key"

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      Text("Settings")
        .font(.largeTitle)
        .bold()

      Divider()

      Text("Default Chat Model")
        .font(.title3)
        .bold()

      Picker("Select Default Model", selection: $selectedDefaultModel) {
        Text("None").tag(nil as ChatModel?)
        ForEach(viewModel.availableModels) { model in
          Text(model.name).tag(model as ChatModel?)
        }
      }
      .frame(maxWidth: 420)

      Text("OpenAI Settings")
        .font(.title3)
        .bold()

      Toggle("Enable OpenAI", isOn: $isOpenAIEnabled)

      if isOpenAIEnabled {
        SecureField("Enter OpenAI API Key", text: $openAIApiKey)
          .textFieldStyle(RoundedBorderTextFieldStyle())
          .padding(.vertical, 5)
          .frame(maxWidth: 420)
      }

      Text("Gemini Settings")
        .font(.title3)
        .bold()

      Toggle("Enable Gemini", isOn: $isGeminiEnabled)

      if isGeminiEnabled {
        SecureField("Enter Gemini API Key", text: $geminiApiKey)
          .textFieldStyle(RoundedBorderTextFieldStyle())
          .padding(.vertical, 5)
          .frame(maxWidth: 420)
      }

      Text("Anthropic Settings")
        .font(.title3)
        .bold()

      Toggle("Enable Claude", isOn: $isAnthropicEnabled)

      if isAnthropicEnabled {
        SecureField("Enter Anthropic API Key", text: $anthropicApiKey)
          .textFieldStyle(RoundedBorderTextFieldStyle())
          .padding(.vertical, 5)
          .frame(maxWidth: 420)
      }

      Button("Save Settings") {
        saveSettings()
      }
      .buttonStyle(.bordered)

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

      isAnthropicEnabled = existingSettings.isAnthropicEnabled
      anthropicApiKey = KeychainHelper.shared.load(for: anthropicApiKeyIdentifier) ?? ""

      if let defaultModel = existingSettings.defaultModel,
        let defaultModel = viewModel.availableModels.first(where: { $0.name == defaultModel.name })
      {
        selectedDefaultModel = defaultModel
      }
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

  private func saveSettings() {
    KeychainHelper.shared.save(
      openAIApiKey.trimmingCharacters(in: .whitespacesAndNewlines), for: openAIApiKeyIdentifier)
    KeychainHelper.shared.save(
      geminiApiKey.trimmingCharacters(in: .whitespacesAndNewlines), for: geminiApiKeyIdentifier)
    KeychainHelper.shared.save(
      anthropicApiKey.trimmingCharacters(in: .whitespacesAndNewlines), for: anthropicApiKeyIdentifier)

    if let existingSettings = settings.first {
      existingSettings.isOpenAIEnabled = isOpenAIEnabled
      existingSettings.isGeminiEnabled = isGeminiEnabled
      existingSettings.isAnthropicEnabled = isAnthropicEnabled

      if let selectedModel = selectedDefaultModel {
        existingSettings.defaultModel = selectedModel
      } else {
        existingSettings.defaultModel = nil
      }
    }
  }
}
