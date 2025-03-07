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
  @State private var apiKey: String = ""

  private let apiKeyIdentifier = "openai_api_key"

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      Text("Settings")
        .font(.largeTitle)
        .bold()

      Toggle("Enable OpenAI", isOn: $isOpenAIEnabled)
        .onChange(of: isOpenAIEnabled) {
          updateSettings()
        }

      if isOpenAIEnabled {
        SecureField("Enter OpenAI API Key", text: $apiKey)
          .textFieldStyle(RoundedBorderTextFieldStyle())
          .padding(.vertical, 5)

        Button("Save API Key") {
          KeychainHelper.shared.save(apiKey, for: apiKeyIdentifier)
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
      apiKey = KeychainHelper.shared.load(for: apiKeyIdentifier) ?? ""
    } else {
      let newSettings = Settings(isOpenAIEnabled: false, openAIAPIKeyIdentifier: apiKeyIdentifier)
      modelContext.insert(newSettings)
    }
  }

  private func updateSettings() {
    if let existingSettings = settings.first {
      existingSettings.isOpenAIEnabled = isOpenAIEnabled
      existingSettings.openAIAPIKeyIdentifier = apiKeyIdentifier
    }
  }
}
