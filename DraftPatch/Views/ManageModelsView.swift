//
//  ManageModelsView.swift
//  DraftPatch
//
//  Created by Robert DeLuca on 4/3/25.
//

import SwiftData
import SwiftUI

struct ManageModelsView: View {
  @StateObject private var vm: ManageModelsViewModel

  @Environment(\.modelContext) private var modelContext
  @Environment(\.dismiss) private var dismiss

  init(availableModels: [ChatModel], modelContext: ModelContext) {
    _vm = StateObject(
      wrappedValue: ManageModelsViewModel(availableModels: availableModels, modelContext: modelContext))
  }

  var body: some View {
    let groups = vm.groupedModels

    Group {
      if vm.originalModels.isEmpty {
        Text("No models loaded.")
          .foregroundColor(.gray)
          .padding(40)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else if vm.filteredModels.isEmpty && !vm.searchText.isEmpty {
        Text("No models available matching '\(vm.searchText)'.")
          .foregroundColor(.gray)
          .padding(40)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        List {
          ForEach(groups, id: \.provider) { group in
            sectionView(for: group)
          }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
      }
    }
    .searchable(text: $vm.searchText, isPresented: $vm.searchFieldFocused)
    .navigationTitle("Manage Models")
    .toolbar {
      ToolbarItem(placement: .cancellationAction) {
        if vm.isEditing {
          Button("Cancel") {
            vm.cancelEdits()
          }
        }
      }
      ToolbarItem(placement: .primaryAction) {
        Button(vm.isEditing ? "Save" : "Edit") {
          if vm.isEditing {
            vm.saveChanges()
          } else {
            vm.initializeEditsForEditing()
            vm.isEditing = true
          }
        }
        .disabled(vm.isEditing && !vm.hasChanges)
      }
      ToolbarItemGroup(placement: .keyboard) {
        Button {
          vm.searchFieldFocused = true
        } label: {
          Label("Focus Search", systemImage: "magnifyingglass")
        }
        .keyboardShortcut("f", modifiers: .command)
      }
    }
    .onAppear {
      vm.modelContext = modelContext
    }
  }

  @ViewBuilder
  private func modelRow(for model: ChatModel) -> some View {
    let modelBinding = vm.binding(for: model)
    let isExpanded = vm.expandedModels.contains(model.id)

    if vm.isEditing {
      DisclosureGroup(
        isExpanded: Binding(
          get: { vm.expandedModels.contains(model.id) },
          set: { shouldExpand in
            if shouldExpand { vm.expandedModels.insert(model.id) } else { vm.expandedModels.remove(model.id) }
          }
        )
      ) {
        VStack(alignment: .leading, spacing: 15) {
          HStack {
            Text("Display Name:")
            Spacer()
            TextField("Display Name", text: modelBinding.displayName)
              .textFieldStyle(RoundedBorderTextFieldStyle()).labelsHidden()
          }
          Divider()

          if modelBinding.wrappedValue.defaultTemperature != nil {
            VStack(alignment: .leading) {
              let tempValue = modelBinding.wrappedValue.defaultTemperature!
              let tempDisplay = String(format: "%.2f", tempValue)
              let sliderBinding = vm.optionalDoubleBinding(
                for: model.id, keyPath: \.defaultTemperature, nilValue: -1.0)
              Text("Temperature: \(tempDisplay)")
              Slider(value: sliderBinding, in: 0.0...2.0, step: 0.05)
              HStack {
                Text("Randomness control").font(.caption).foregroundColor(.secondary)
                Spacer()
                Button("Use Default") { modelBinding.wrappedValue.defaultTemperature = nil }.buttonStyle(
                  .link)
              }
            }
          } else {
            HStack {
              Text("Temperature:")
              Spacer()
              Button("Set") { modelBinding.wrappedValue.defaultTemperature = vm.defaultOverrideTemperature }
            }
          }

          if modelBinding.wrappedValue.defaultMaxTokens != nil {
            VStack(alignment: .leading) {
              HStack(alignment: .firstTextBaseline) {
                Text("Max Tokens:")
                Spacer()
                TextField(
                  "Tokens", text: vm.optionalIntStringBinding(for: model.id, keyPath: \.defaultMaxTokens)
                )
                .textFieldStyle(RoundedBorderTextFieldStyle()).frame(maxWidth: 100).multilineTextAlignment(
                  .trailing)
                Button {
                  modelBinding.wrappedValue.defaultMaxTokens = nil
                } label: {
                  Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain).foregroundColor(.secondary)
              }
              Text("Max completion length").font(.caption).foregroundColor(.secondary)
            }
          } else {
            HStack {
              Text("Max Tokens:")
              Spacer()
              Button("Set") { modelBinding.wrappedValue.defaultMaxTokens = vm.defaultOverrideMaxTokens }
            }
          }

          if modelBinding.wrappedValue.defaultSystemPrompt != nil {
            VStack(alignment: .leading) {
              HStack {
                Text("System Prompt:")
                Spacer()
                if !(modelBinding.wrappedValue.defaultSystemPrompt?.isEmpty ?? true) {
                  Button("Clear") { modelBinding.wrappedValue.defaultSystemPrompt = nil }.buttonStyle(.link)
                }
              }
              TextEditor(text: vm.optionalStringBinding(for: model.id, keyPath: \.defaultSystemPrompt))
                .frame(minHeight: 60, maxHeight: 150).border(Color.secondary.opacity(0.5), width: 1).font(
                  .body.monospaced())
              Text("Default instructions").font(.caption).foregroundColor(.secondary)
            }
          } else {
            HStack {
              Text("System Prompt:")
              Spacer()
              Button("Set") { modelBinding.wrappedValue.defaultSystemPrompt = "" }
            }
          }
        }
        .padding(.leading, 10).padding(.vertical, 10)
      } label: {
        HStack {
          VStack(alignment: .leading) {
            Text(model.name).font(.body.bold())
            Text(modelBinding.wrappedValue.displayName).font(.caption).foregroundColor(.secondary)
          }
          Spacer()
          Toggle("Enabled", isOn: modelBinding.enabled).labelsHidden()
        }
        .contentShape(Rectangle()).padding(.vertical, 4).padding(.trailing, vm.listRowTrailingPadding)
      }
      .padding(.bottom, isExpanded ? 5 : 0)
    } else {
      HStack {
        VStack(alignment: .leading) {
          Text(model.displayName).font(.body)
          if model.displayName != model.name { Text(model.name).font(.caption).foregroundColor(.secondary) }
        }
        Spacer()
        Toggle("Enabled", isOn: .constant(model.enabled))
          .labelsHidden().disabled(true)
      }
      .padding(.vertical, 8).padding(.trailing, vm.listRowTrailingPadding)
    }
  }

  @ViewBuilder
  private func sectionHeader(for provider: LLMProvider, models: [ChatModel]) -> some View {
    HStack {
      Text(provider.displayName).font(.title3.bold())
        .contentShape(Rectangle())
        .onTapGesture { vm.toggleCollapse(for: provider) }

      Spacer()

      if vm.isEditing && !models.isEmpty {
        HStack(spacing: 10) {
          Button("Enable All") { vm.setEnabledStateForAll(in: models, enabled: true) }
            .buttonStyle(.link).disabled(vm.areAllEnabled(in: models))
          Button("Disable All") { vm.setEnabledStateForAll(in: models, enabled: false) }
            .buttonStyle(.link).disabled(vm.areAllDisabled(in: models))
        }
        .padding(.trailing, vm.listRowTrailingPadding - 4)
      }
    }
    .padding(.vertical, 4)
  }

  private func sectionView(for group: (provider: LLMProvider, models: [ChatModel])) -> some View {
    let isCollapsed = vm.collapsedProviders.contains(group.provider)

    return Section {
      if !isCollapsed && !group.models.isEmpty {
        ForEach(group.models) { model in
          modelRow(for: model)
            .id("\(model.id)-\(vm.isEditing ? "edit" : "view")")
        }
      }
    } header: {
      sectionHeader(for: group.provider, models: group.models)
    }
  }
}
