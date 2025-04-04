//
//  ManageModelsViewModel.swift
//  DraftPatch
//
//  Created by Robert DeLuca on 4/4/25.
//

import Combine
import SwiftData
import SwiftUI

struct ModelEditState: Hashable {
  var displayName: String
  var enabled: Bool
  var defaultTemperature: Double?
  var defaultSystemPrompt: String?
  var defaultTopP: Double?
  var defaultMaxTokens: Int?

  static func from(_ model: ChatModel) -> ModelEditState {
    ModelEditState(
      displayName: model.displayName,
      enabled: model.enabled,
      defaultTemperature: model.defaultTemperature,
      defaultSystemPrompt: model.defaultSystemPrompt,
      defaultTopP: model.defaultTopP,
      defaultMaxTokens: model.defaultMaxTokens
    )
  }
}

@MainActor
class ManageModelsViewModel: ObservableObject {

  let originalModels: [ChatModel]
  var modelContext: ModelContext

  @Published var searchText: String = ""
  @Published var editedModels: [String: ModelEditState] = [:]
  @Published var isEditing: Bool = false
  @Published var searchFieldFocused: Bool = false
  @Published var expandedModels: Set<String> = []
  @Published var collapsedProviders: Set<LLMProvider> = []

  let defaultOverrideTemperature: Double = 0.7
  let defaultOverrideMaxTokens: Int = 2048
  let defaultOverrideTopP: Double = 0.9
  let listRowTrailingPadding: CGFloat = 10

  var filteredModels: [ChatModel] {
    if searchText.isEmpty {
      return originalModels
    } else {
      return originalModels.filter {
        let currentDisplayName = editedModels[$0.id]?.displayName ?? $0.displayName
        return currentDisplayName.localizedCaseInsensitiveContains(searchText)
          || $0.name.localizedCaseInsensitiveContains(searchText)
      }
    }
  }

  var groupedModels: [(provider: LLMProvider, models: [ChatModel])] {
    let providers: [LLMProvider] = LLMProvider.allCases
    return providers.compactMap { provider in
      let models =
        filteredModels
        .filter { $0.provider == provider }
        .sorted {
          let name1 = editedModels[$0.id]?.displayName ?? $0.displayName
          let name2 = editedModels[$1.id]?.displayName ?? $1.displayName
          return name1.localizedCaseInsensitiveCompare(name2) == .orderedAscending
        }
      return models.isEmpty ? nil : (provider, models)
    }
  }

  var hasChanges: Bool {
    editedModels.contains { id, editState in
      guard let originalModel = originalModels.first(where: { $0.id == id }) else {
        return true
      }
      return editState != ModelEditState.from(originalModel)
    }
  }

  init(availableModels: [ChatModel], modelContext: ModelContext) {
    self.originalModels = availableModels
    self.modelContext = modelContext
    self.editedModels = [:]
  }

  func binding(for model: ChatModel) -> Binding<ModelEditState> {
    Binding(
      get: {
        self.editedModels[model.id] ?? ModelEditState.from(model)
      },
      set: { newValue in
        if let originalModel = self.originalModels.first(where: { $0.id == model.id }),
          newValue == ModelEditState.from(originalModel)
        {
          self.editedModels.removeValue(forKey: model.id)
        } else {
          self.editedModels[model.id] = newValue
        }
      }
    )
  }

  func optionalDoubleBinding(
    for modelId: String, keyPath: WritableKeyPath<ModelEditState, Double?>, nilValue: Double = -1.0
  ) -> Binding<Double> {
    Binding(
      get: {
        // Ensure the edit state exists before trying to access it
        if self.editedModels[modelId] == nil,
          let model = self.originalModels.first(where: { $0.id == modelId })
        {
          self.editedModels[modelId] = ModelEditState.from(model)
        }
        return self.editedModels[modelId]?[keyPath: keyPath] ?? nilValue
      },
      set: { newValue in
        // Ensure the edit state exists before trying to set it
        if self.editedModels[modelId] == nil,
          let model = self.originalModels.first(where: { $0.id == modelId })
        {
          self.editedModels[modelId] = ModelEditState.from(model)
        }
        guard self.editedModels[modelId] != nil else { return }
        if newValue == nilValue {
          self.editedModels[modelId]?[keyPath: keyPath] = nil
        } else {
          self.editedModels[modelId]?[keyPath: keyPath] = newValue
        }
      }
    )
  }

  func optionalIntStringBinding(for modelId: String, keyPath: WritableKeyPath<ModelEditState, Int?>)
    -> Binding<String>
  {
    Binding(
      get: {
        if self.editedModels[modelId] == nil,
          let model = self.originalModels.first(where: { $0.id == modelId })
        {
          self.editedModels[modelId] = ModelEditState.from(model)
        }
        if let value = self.editedModels[modelId]?[keyPath: keyPath] {
          return String(value)
        } else {
          return ""
        }
      },
      set: { newValue in
        if self.editedModels[modelId] == nil,
          let model = self.originalModels.first(where: { $0.id == modelId })
        {
          self.editedModels[modelId] = ModelEditState.from(model)
        }
        guard self.editedModels[modelId] != nil else { return }
        if let intValue = Int(newValue), intValue >= 0 {
          self.editedModels[modelId]?[keyPath: keyPath] = intValue
        } else if newValue.isEmpty {
          self.editedModels[modelId]?[keyPath: keyPath] = nil
        }
      }
    )
  }

  func optionalStringBinding(for modelId: String, keyPath: WritableKeyPath<ModelEditState, String?>)
    -> Binding<String>
  {
    Binding(
      get: {
        if self.editedModels[modelId] == nil,
          let model = self.originalModels.first(where: { $0.id == modelId })
        {
          self.editedModels[modelId] = ModelEditState.from(model)
        }
        return self.editedModels[modelId]?[keyPath: keyPath] ?? ""
      },
      set: { newValue in
        if self.editedModels[modelId] == nil,
          let model = self.originalModels.first(where: { $0.id == modelId })
        {
          self.editedModels[modelId] = ModelEditState.from(model)
        }
        guard self.editedModels[modelId] != nil else { return }
        self.editedModels[modelId]?[keyPath: keyPath] = newValue.isEmpty ? nil : newValue
      }
    )
  }

  func toggleEditMode() {
    if isEditing {
      isEditing = false
      cancelEdits()  // Assume toggling off without explicit save means cancel
    } else {
      initializeEditsForEditing()
      isEditing = true
    }
  }

  func initializeEditsForEditing() {
    editedModels = Dictionary(
      uniqueKeysWithValues: originalModels.map { model in
        (model.id, ModelEditState.from(model))
      }
    )
    expandedModels.removeAll()
  }

  func cancelEdits() {
    editedModels.removeAll()
    expandedModels.removeAll()
    isEditing = false
  }

  func saveChanges() {
    let changesToApply = editedModels.filter { id, editState in
      guard let originalModel = originalModels.first(where: { $0.id == id }) else {
        return false
      }
      return editState != ModelEditState.from(originalModel)
    }

    guard !changesToApply.isEmpty else {
      print("No effective changes detected, skipping save.")
      editedModels.removeAll()
      expandedModels.removeAll()
      isEditing = false
      return
    }

    print("Applying changes to \(changesToApply.count) models.")

    var appliedChangeToContext = false
    for (modelId, editState) in changesToApply {
      guard let modelToUpdate = originalModels.first(where: { $0.id == modelId }) else {
        print("Error: Could not find live ChatModel with id \(modelId) to update.")
        continue
      }

      modelToUpdate.displayName = editState.displayName
      modelToUpdate.enabled = editState.enabled
      modelToUpdate.defaultTemperature = editState.defaultTemperature
      modelToUpdate.defaultSystemPrompt = editState.defaultSystemPrompt
      modelToUpdate.defaultTopP = editState.defaultTopP
      modelToUpdate.defaultMaxTokens = editState.defaultMaxTokens
      print("Updating model: \(modelId)")
      appliedChangeToContext = true
    }

    if appliedChangeToContext && modelContext.hasChanges {
      do {
        try modelContext.save()
        print("Successfully saved model changes to SwiftData.")
      } catch {
        print("Error saving model changes to SwiftData: \(error)")
        // Consider adding error handling for the user here
      }
    } else {
      print("No changes needed saving to SwiftData context.")
    }

    editedModels.removeAll()
    expandedModels.removeAll()
    isEditing = false
  }

  func toggleCollapse(for provider: LLMProvider) {
    withAnimation(.easeInOut(duration: 0.2)) {
      if collapsedProviders.contains(provider) {
        collapsedProviders.remove(provider)
      } else {
        collapsedProviders.insert(provider)
      }
    }
  }

  func setEnabledStateForAll(in models: [ChatModel], enabled: Bool) {
    for model in models {
      if editedModels[model.id] != nil {
        editedModels[model.id]?.enabled = enabled
      } else {
        var currentState = ModelEditState.from(model)
        currentState.enabled = enabled
        editedModels[model.id] = currentState
      }
    }
  }

  func areAllEnabled(in models: [ChatModel]) -> Bool {
    !models.isEmpty
      && models.allSatisfy { model in
        editedModels[model.id]?.enabled ?? model.enabled
      }
  }

  func areAllDisabled(in models: [ChatModel]) -> Bool {
    !models.isEmpty
      && models.allSatisfy { model in
        !(editedModels[model.id]?.enabled ?? model.enabled)
      }
  }
}
