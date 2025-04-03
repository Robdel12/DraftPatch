import SwiftUI

struct ManageModelsView: View {
  @EnvironmentObject var viewModel: DraftPatchViewModel
  @Environment(\.dismiss) private var dismiss
  @State private var searchText: String = ""
  @State private var editedModels: [String: (displayName: String, enabled: Bool)] = [:]
  @State private var isEditing: Bool = false
  @State private var searchFieldFocused: Bool = false
  let onSave: ([String: (displayName: String, enabled: Bool)]) -> Void

  // Filter the models based on the search text
  var filteredModels: [ChatModel] {
    if searchText.isEmpty {
      return viewModel.availableModels
    } else {
      return viewModel.availableModels.filter {
        $0.displayName.localizedCaseInsensitiveContains(searchText)
      }
    }
  }

  // Group the filtered models by their provider in a defined order
  var groupedModels: [(provider: LLMProvider, models: [ChatModel])] {
    let providers: [LLMProvider] = [.ollama, .openai, .gemini, .anthropic]
    return providers.compactMap { provider in
      let models = filteredModels.filter { $0.provider == provider }
      return models.isEmpty ? nil : (provider, models)
    }
  }

  // Helper view for a model row
  private func modelRow(for model: ChatModel) -> some View {
    let binding = Binding(
      get: {
        editedModels[model.name] ?? (model.displayName, model.enabled)
      },
      set: { newValue in
        editedModels[model.name] = newValue
      }
    )

    return HStack(alignment: .top) {
      VStack(alignment: .leading, spacing: 4) {
        if isEditing {
          Text(model.name)
            .font(.body.bold())
          TextField(
            "Display Name",
            text: Binding(
              get: { binding.wrappedValue.displayName },
              set: { binding.wrappedValue = ($0, binding.wrappedValue.enabled) }
            )
          )
          .textFieldStyle(RoundedBorderTextFieldStyle())
          .frame(maxWidth: 400)
          .font(.body)
        } else {
          Text(binding.wrappedValue.displayName)
            .font(.body)
        }
      }

      Spacer()

      Toggle(
        "Enabled",
        isOn: Binding(
          get: { binding.wrappedValue.enabled },
          set: {
            binding.wrappedValue = (binding.wrappedValue.displayName, $0)
          }
        )
      )
      .labelsHidden()
      .toggleStyle(SwitchToggleStyle())
    }
    .padding(.vertical, 8)
  }

  // Helper view for a section of models for a provider
  private func sectionView(for group: (provider: LLMProvider, models: [ChatModel])) -> some View {
    Section(header: Text(group.provider.displayName).font(.title3.bold())) {
      ForEach(group.models) { model in
        modelRow(for: model)
      }
    }
  }

  var body: some View {
    // Extract groupedModels into a local constant to simplify the expression
    let groups = groupedModels

    return Group {
      if filteredModels.isEmpty {
        Text("No models available matching your search criteria.")
          .foregroundColor(.gray)
          .padding(40)
      } else {
        List {
          ForEach(groups, id: \.provider) { group in
            sectionView(for: group)
          }
        }
        .listStyle(SidebarListStyle())
      }
    }
    .searchable(text: $searchText, isPresented: $searchFieldFocused)
    .navigationTitle("Manage Models")
    .toolbar {
      if isEditing {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            editedModels.removeAll()
            isEditing = false
          }
        }
      }
      ToolbarItem(placement: .automatic) {
        Button(isEditing ? "Save" : "Edit") {
          if isEditing {
            onSave(editedModels)
            editedModels.removeAll()
          }
          isEditing.toggle()
        }
      }
      ToolbarItemGroup(placement: .keyboard) {
        Button(action: {
          searchFieldFocused = true
        }) {
          Text("Focus Search")
        }
        .keyboardShortcut("f", modifiers: .command)
      }
    }
  }
}
