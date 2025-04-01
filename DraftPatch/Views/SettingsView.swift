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

  @State private var isOllamaEnabled: Bool = false
  @State private var ollamaAPIURL: String = "http://localhost:11434"

  @State private var isOpenAIEnabled: Bool = false
  @State private var openAIApiKey: String = ""

  @State private var isGeminiEnabled: Bool = false
  @State private var geminiApiKey: String = ""

  @State private var isAnthropicEnabled: Bool = false
  @State private var anthropicApiKey: String = ""

  private var isAnyLLMEnabled: Bool {
    return isOllamaEnabled || isOpenAIEnabled || isGeminiEnabled || isAnthropicEnabled
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          Text("Default Chat Model")
            .font(.title3)
            .bold()

          Divider()

          if isAnyLLMEnabled && viewModel.availableModels.isEmpty == false {
            Picker("Select Default Model", selection: $selectedDefaultModel) {
              Text("None").tag(nil as ChatModel?)
              ForEach(viewModel.availableModels) { model in
                Text(model.name).tag(model as ChatModel?)
              }
            }
            .frame(maxWidth: 420)
          } else {
            Text("Enable an LLM provider to pick a default")
              .foregroundColor(.white)
              .font(.body)
          }

          Text("Ollama Settings")
            .font(.title3)
            .bold()

          Divider()

          Toggle("Enable Ollama", isOn: $isOllamaEnabled)

          if isOllamaEnabled {
            TextField("Ollama API URL", text: $ollamaAPIURL)
              .textFieldStyle(RoundedBorderTextFieldStyle())
              .padding(.vertical, 5)
              .frame(maxWidth: 420)
          }

          Text("OpenAI Settings")
            .font(.title3)
            .bold()

          Divider()

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

          Divider()

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

          Divider()

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
        .navigationTitle("Settings")
        .onAppear {
          loadSettings()
        }
        .onDisappear {
          Task {
            await viewModel.loadLLMs()
          }
        }
      }
    }
  }

  private func loadSettings() {
    guard let existingSettings = settings.first else {
      createInitialSettings()
      return
    }

    if let defaultModel = existingSettings.defaultModel {
      if let matchedModel = viewModel.availableModels.first(where: { $0.name == defaultModel.name }) {
        selectedDefaultModel = matchedModel
      } else {
        selectedDefaultModel = nil
      }
    } else {
      selectedDefaultModel = nil
    }

    if let ollamaConfig = existingSettings.ollamaConfig {
      isOllamaEnabled = ollamaConfig.enabled
      ollamaAPIURL = ollamaConfig.endpointURL.absoluteString
    } else {
      let newConfig = OllamaConfig(enabled: false)
      existingSettings.ollamaConfig = newConfig
      modelContext.insert(newConfig)
      isOllamaEnabled = newConfig.enabled
    }

    if let openAIConfig = existingSettings.openAIConfig {
      isOpenAIEnabled = openAIConfig.enabled
      if let identifier = openAIConfig.apiKeyIdentifier {
        openAIApiKey = KeychainHelper.shared.load(for: identifier) ?? ""
      }
    } else {
      let newConfig = OpenAIConfig(enabled: false, apiKeyIdentifier: "openai_api_key")
      existingSettings.openAIConfig = newConfig
      modelContext.insert(newConfig)
      isOpenAIEnabled = newConfig.enabled
      openAIApiKey = ""
    }

    if let geminiConfig = existingSettings.geminiConfig {
      isGeminiEnabled = geminiConfig.enabled
      if let identifier = geminiConfig.apiKeyIdentifier {
        geminiApiKey = KeychainHelper.shared.load(for: identifier) ?? ""
      }
    } else {
      let newConfig = GeminiConfig(enabled: false, apiKeyIdentifier: "gemini_api_key")
      existingSettings.geminiConfig = newConfig
      modelContext.insert(newConfig)
      isGeminiEnabled = newConfig.enabled
      geminiApiKey = ""
    }

    if let anthropicConfig = existingSettings.anthropicConfig {
      isAnthropicEnabled = anthropicConfig.enabled
      if let identifier = anthropicConfig.apiKeyIdentifier {
        anthropicApiKey = KeychainHelper.shared.load(for: identifier) ?? ""
      }
    } else {
      let newConfig = AnthropicConfig(enabled: false, apiKeyIdentifier: "anthropic_api_key")
      existingSettings.anthropicConfig = newConfig
      modelContext.insert(newConfig)
      isAnthropicEnabled = newConfig.enabled
      anthropicApiKey = ""
    }
  }

  private func createInitialSettings() {
    let newSettings = Settings()
    modelContext.insert(newSettings)

    let openAIConfig = OpenAIConfig(enabled: false, apiKeyIdentifier: "openai_api_key")
    let geminiConfig = GeminiConfig(enabled: false, apiKeyIdentifier: "gemini_api_key")
    let anthropicConfig = AnthropicConfig(enabled: false, apiKeyIdentifier: "anthropic_api_key")

    newSettings.openAIConfig = openAIConfig
    newSettings.geminiConfig = geminiConfig
    newSettings.anthropicConfig = anthropicConfig

    modelContext.insert(openAIConfig)
    modelContext.insert(geminiConfig)
    modelContext.insert(anthropicConfig)

    newSettings.defaultModel = nil

    isOpenAIEnabled = false
    openAIApiKey = ""
    isGeminiEnabled = false
    geminiApiKey = ""
    isAnthropicEnabled = false
    anthropicApiKey = ""
  }

  private func saveSettings() {
    guard let existingSettings = settings.first else {
      return
    }

    existingSettings.defaultModel = selectedDefaultModel

    if let ollamaConfig = existingSettings.ollamaConfig {
      ollamaConfig.enabled = isOllamaEnabled

      if let validURL = URL(string: ollamaAPIURL), !ollamaAPIURL.isEmpty {
        ollamaConfig.endpointURL = validURL
      } else {
        // TODO: show in UI
        print("Invalid Ollama API URL provided: \(ollamaAPIURL)")
      }
    }

    if let openAIConfig = existingSettings.openAIConfig {
      openAIConfig.enabled = isOpenAIEnabled
      if let identifier = openAIConfig.apiKeyIdentifier {
        KeychainHelper.shared.save(
          openAIApiKey.trimmingCharacters(in: .whitespacesAndNewlines),
          for: identifier
        )
      }
    }

    if let geminiConfig = existingSettings.geminiConfig {
      geminiConfig.enabled = isGeminiEnabled
      if let identifier = geminiConfig.apiKeyIdentifier {
        KeychainHelper.shared.save(
          geminiApiKey.trimmingCharacters(in: .whitespacesAndNewlines),
          for: identifier
        )
      }
    }

    if let anthropicConfig = existingSettings.anthropicConfig {
      anthropicConfig.enabled = isAnthropicEnabled
      if let identifier = anthropicConfig.apiKeyIdentifier {
        KeychainHelper.shared.save(
          anthropicApiKey.trimmingCharacters(in: .whitespacesAndNewlines),
          for: identifier
        )
      }
    }

    try? modelContext.save()

    Task {
      await viewModel.loadLLMs()
    }
  }
}
