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
          Text("Chat Models")
            .font(.title3)
            .bold()

          Divider()

          if viewModel.availableModels.isEmpty {
            Text("No models available.")
              .foregroundColor(.gray)
          } else {
            Picker("Default Chat Model", selection: $selectedDefaultModel) {
              Text("None").tag(nil as ChatModel?)
              ForEach(viewModel.availableModels.filter { $0.enabled }) { model in
                Text(model.displayName).tag(model as ChatModel?)
              }
            }
            .frame(maxWidth: 420)
          }

          NavigationLink(
            "Manage Models",
            destination: ManageModelsView(
              availableModels: viewModel.availableModels,
              modelContext: modelContext
            )
            .environment(\.modelContext, modelContext))

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

  @MainActor
  private func loadSettings() {
    guard let existingSettings = settings.first ?? createAndReturnInitialSettings() else {
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
      modelContext.insert(newConfig)
      existingSettings.ollamaConfig = newConfig
      isOllamaEnabled = newConfig.enabled
    }

    if let openAIConfig = existingSettings.openAIConfig {
      isOpenAIEnabled = openAIConfig.enabled
      if let identifier = openAIConfig.apiKeyIdentifier {
        openAIApiKey = KeychainHelper.shared.load(for: identifier) ?? ""
      }
    } else {
      let newConfig = OpenAIConfig(enabled: false, apiKeyIdentifier: "openai_api_key")
      modelContext.insert(newConfig)
      existingSettings.openAIConfig = newConfig
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
      modelContext.insert(newConfig)
      existingSettings.geminiConfig = newConfig
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
      modelContext.insert(newConfig)
      existingSettings.anthropicConfig = newConfig
      isAnthropicEnabled = newConfig.enabled
      anthropicApiKey = ""
    }

    try? modelContext.save()
  }

  private func saveSettings() {
    guard let existingSettings = settings.first ?? createAndReturnInitialSettings() else {
      return
    }

    let viewContext = self.modelContext

    if let selected = selectedDefaultModel {
      let selectedModelID = selected.persistentModelID
      let modelInCorrectContext = viewContext.model(for: selectedModelID) as? ChatModel
      existingSettings.defaultModel = modelInCorrectContext
    } else {
      existingSettings.defaultModel = nil
    }

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

    try? viewContext.save()

    DispatchQueue.main.async {
      self.viewModel.settings = existingSettings
    }

    Task {
      await viewModel.loadLLMs()
    }
  }

  private func createAndReturnInitialSettings() -> Settings? {
    let viewContext = self.modelContext

    let newSettings = Settings()
    viewContext.insert(newSettings)

    let ollamaConfig = OllamaConfig(enabled: isOllamaEnabled)
    viewContext.insert(ollamaConfig)
    newSettings.ollamaConfig = ollamaConfig

    let openAIConfig = OpenAIConfig(enabled: isOpenAIEnabled, apiKeyIdentifier: "openai_api_key")
    viewContext.insert(openAIConfig)
    newSettings.openAIConfig = openAIConfig

    let geminiConfig = GeminiConfig(enabled: isGeminiEnabled, apiKeyIdentifier: "gemini_api_key")
    viewContext.insert(geminiConfig)
    newSettings.geminiConfig = geminiConfig

    let anthropicConfig = AnthropicConfig(enabled: isAnthropicEnabled, apiKeyIdentifier: "anthropic_api_key")
    viewContext.insert(anthropicConfig)
    newSettings.anthropicConfig = anthropicConfig

    if let selected = selectedDefaultModel {
      let selectedModelID = selected.persistentModelID
      let modelInCorrectContext = viewContext.model(for: selectedModelID) as? ChatModel
      newSettings.defaultModel = modelInCorrectContext
    } else {
      newSettings.defaultModel = nil
    }

    try? viewContext.save()
    return newSettings
  }
}
