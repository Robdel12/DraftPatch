//
//  ModelPickerPopoverView.swift
//  DraftPatch
//
//  Created by Robert DeLuca on 3/10/25.
//

import SwiftUI

struct ModelPickerPopoverView: View {
  @EnvironmentObject var viewModel: DraftPatchViewModel
  @State private var isPopoverPresented: Bool = false
  @State private var searchText: String = ""
  @State private var isPullingModel: Bool = false
  @State private var downloadProgress: Double = 0.0
  @State private var statusMessage: String = ""
  @State private var downloadCompleted: Bool = false
  @State private var downloadFailed: Bool = false
  @State private var errorMessage: String = ""
  @State private var currentDigest: String = ""
  @State private var selectedIndex: Int = 0

  @FocusState private var isSearchFieldFocused: Bool

  // Filtered models based on search text
  var searchedModels: [ChatModel] {
    let enabledModels = viewModel.availableModels.filter { $0.enabled }

    if searchText.isEmpty {
      return enabledModels
    } else {
      return enabledModels.filter { $0.displayName.localizedCaseInsensitiveContains(searchText) }
    }
  }

  // Models sorted for display and navigation (Provider -> Last Used)
  var flattenedSortedModels: [ChatModel] {
    searchedModels.sorted {
      if $0.provider != $1.provider {
        // Sort providers alphabetically
        return $0.provider.displayName < $1.provider.displayName
      }
      // Within the same provider, sort by last used date (most recent first)
      guard let date1 = $0.lastUsed, let date2 = $1.lastUsed else {
        return $0.lastUsed != nil
      }
      return date1 > date2
    }
  }

  // Grouped models for section display
  var groupedModels: [LLMProvider: [ChatModel]] {
    Dictionary(grouping: flattenedSortedModels, by: { $0.provider })
  }

  // Sorted providers that have models matching the search
  var sortedProviders: [LLMProvider] {
    groupedModels.keys.sorted { $0.displayName < $1.displayName }
  }

  var canDownloadNewModel: Bool {
    !searchText.isEmpty
      && !viewModel.availableModels
        .contains(where: { $0.displayName.localizedCaseInsensitiveContains(searchText) })
  }

  var body: some View {
    Button {
      isPopoverPresented.toggle()
    } label: {
      HStack {
        Text(viewModel.selectedModel?.displayName ?? "")
        Image(systemName: "chevron.down")
      }
      .padding(8)
      .contentShape(Rectangle())
    }
    .accessibilityLabel(viewModel.selectedModel?.displayName ?? "")
    .accessibilityIdentifier("ModelSelectorButton")
    .keyboardShortcut("e", modifiers: .command)
    .buttonStyle(.plain)
    .background(
      RoundedRectangle(cornerRadius: 8)
        .stroke(Color.gray, lineWidth: 2)
    )
    .popover(isPresented: $isPopoverPresented) {
      popoverContent
    }
  }

  private var popoverContent: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Select Model")
        .font(.headline)
      searchBarView
      Divider()
      modelListView
    }
    .padding()
    .frame(width: 300)
    .onChange(of: downloadCompleted) { _, completed in
      if completed {
        DispatchQueue.main.async {
          self.resetDownloadState()

          Task {
            await viewModel.loadLLMs()
          }
        }
      }
    }
    .onChange(of: flattenedSortedModels.count) { _, newCount in
      if selectedIndex >= newCount + (canDownloadNewModel ? 1 : 0) {
        selectedIndex = newCount > 0 ? newCount - 1 : 0
      }
    }
    .onChange(of: searchText) { _, _ in
      selectedIndex = 0
    }
  }

  private var searchBarView: some View {
    HStack {
      Image(systemName: "magnifyingglass")
        .foregroundColor(.secondary)
      TextField("Search or download a model", text: $searchText)
        .textFieldStyle(RoundedBorderTextFieldStyle())
        .accessibilityIdentifier("ModelSearchField")
        .focused($isSearchFieldFocused)
        .onAppear {
          isSearchFieldFocused = true
          selectedIndex = 0
        }
        .onSubmit {
          if selectedIndex < flattenedSortedModels.count {
            selectModel(at: selectedIndex)
          } else if canDownloadNewModel {
            pullModel(modelName: searchText)
          }
        }
        .onKeyPress(.upArrow) {
          navigateUp()
          return .handled
        }
        .onKeyPress(.downArrow) {
          navigateDown()
          return .handled
        }
        .onKeyPress { keyPress in
          if keyPress.phase == .down {
            switch keyPress.characters {
            case "n" where keyPress.modifiers.contains(.control):
              navigateDown()
              return .handled
            case "p" where keyPress.modifiers.contains(.control):
              navigateUp()
              return .handled
            case "g" where keyPress.modifiers.contains(.control):
              isPopoverPresented = false
              return .handled
            default:
              return .ignored
            }
          }
          return .ignored
        }
    }
  }

  private var modelListView: some View {
    ScrollViewReader { proxy in
      ScrollView {
        VStack(alignment: .leading, spacing: 0) {
          if flattenedSortedModels.isEmpty && !canDownloadNewModel {
            Text("No matching models found")
              .foregroundColor(.secondary)
              .padding(.vertical, 8)
          } else {
            ForEach(sortedProviders, id: \.self) { provider in
              if let models = groupedModels[provider], !models.isEmpty {
                Section(
                  header: Text(provider.displayName).font(.caption).foregroundColor(.secondary).padding(
                    .vertical,
                    4
                  )
                ) {
                  ForEach(models) { model in
                    if let flatIndex = flattenedSortedModels.firstIndex(where: { $0.id == model.id }) {
                      ModelPickerRow(
                        model: model,
                        isSelected: model.id == viewModel.selectedModel?.id,
                        isHighlighted: selectedIndex == flatIndex
                      )
                      .id(model.id)
                      .onTapGesture {
                        selectModel(at: flatIndex)
                      }
                      .contextMenu {
                        if model.provider == .ollama {
                          Button(role: .destructive) {
                            deleteModel(modelName: model.name)
                          } label: {
                            Text("Delete")
                          }
                        }
                      }
                    }
                  }
                }
              }
            }

            if canDownloadNewModel {
              Divider().padding(.vertical, 4)

              if isPullingModel {
                VStack(alignment: .leading, spacing: 8) {
                  Text(statusMessage)
                    .foregroundColor(.secondary)

                  ProgressView(value: downloadProgress)
                    .progressViewStyle(LinearProgressViewStyle())
                }
                .padding(8)
              } else if downloadCompleted {
                HStack {
                  Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                  Text("Download complete!")
                    .foregroundColor(.green)
                }
                .padding(8)
              } else if downloadFailed {
                VStack(alignment: .leading, spacing: 4) {
                  HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                      .foregroundColor(.red)
                    Text("Download failed")
                      .foregroundColor(.red)
                  }
                  Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .lineLimit(2)
                }
                .padding(8)
              } else {
                Button(action: {
                  pullModel(modelName: searchText)
                }) {
                  HStack {
                    Image(systemName: "arrow.down.circle")
                      .foregroundColor(.accentColor)
                    Text("Download \(searchText)")
                      .foregroundColor(.accentColor)
                    Spacer()
                  }
                  .padding(8)
                  .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                .background(
                  selectedIndex == flattenedSortedModels.count ? Color.accentColor.opacity(0.2) : Color.clear
                )
                .cornerRadius(4)
                .id("download_\(searchText)")
              }
            }
          }
        }
      }
      .frame(
        height: min(
          350,
          CGFloat(
            flattenedSortedModels.count * 36 + sortedProviders.count * 24 + (canDownloadNewModel ? 60 : 0)
          )
        )
      )
      .onChange(of: selectedIndex) { _, newIndex in
        let targetId: AnyHashable

        if newIndex < flattenedSortedModels.count {
          targetId = flattenedSortedModels[newIndex].id
        } else if canDownloadNewModel {
          targetId = "download_\(searchText)"
        } else {
          return
        }

        withAnimation {
          proxy.scrollTo(targetId, anchor: .bottom)
        }
      }
    }
  }

  private func navigateUp() {
    if selectedIndex > 0 {
      selectedIndex -= 1
    }
  }

  private func navigateDown() {
    let maxIndex = flattenedSortedModels.count + (canDownloadNewModel ? 1 : 0) - 1
    if selectedIndex < maxIndex {
      selectedIndex += 1
    }
  }

  private func selectModel(at index: Int) {
    if index < flattenedSortedModels.count {
      viewModel.selectedModel = flattenedSortedModels[index]
      isPopoverPresented = false
    }
  }

  private func deleteModel(modelName: String) {
    Task {
      do {
        try await OllamaService.shared.deleteModel(modelName: modelName)
        viewModel.availableModels.removeAll { $0.name == modelName }
        if let firstAvailable = viewModel.availableModels.first(where: { $0.enabled }),
          viewModel.selectedModel?.name == modelName
        {
          viewModel.selectedModel = firstAvailable
        }
        print("Model deleted successfully.")
      } catch {
        print("Error deleting model:", error)
        errorMessage = error.localizedDescription
      }
    }
  }

  private func pullModel(modelName: String) {
    // Reset states
    statusMessage = "Preparing download..."
    downloadProgress = 0.0
    isPullingModel = true
    downloadCompleted = false
    downloadFailed = false
    errorMessage = ""
    currentDigest = ""

    Task {
      do {
        for try await json in OllamaService.shared.pullModel(modelName: modelName) {
          await MainActor.run {
            if let status = json["status"] as? String {
              statusMessage = status

              if status == "success" {
                downloadProgress = 1.0
                isPullingModel = false
                downloadCompleted = true
                return
              }
            }

            if let digest = json["digest"] as? String {
              currentDigest = digest
            }

            if let total = json["total"] as? Double, let completed = json["completed"] as? Double, total > 0 {
              let progress = completed / total
              downloadProgress = progress
              statusMessage = "Downloading \(Int(progress * 100))% of \(formatSize(bytes: Int64(total)))"
            }
          }
        }
      } catch {
        await MainActor.run {
          isPullingModel = false
          downloadFailed = true
          errorMessage = error.localizedDescription
        }
        DispatchQueue.main.async {
          self.resetDownloadState()
          Task {
            await viewModel.loadLLMs()
          }
        }
      }
    }
  }

  private func formatSize(bytes: Int64) -> String {
    let formatter = ByteCountFormatter()
    formatter.allowedUnits = [.useKB, .useMB, .useGB]
    formatter.countStyle = .file
    return formatter.string(fromByteCount: bytes)
  }

  @MainActor
  private func resetDownloadState() {
    downloadCompleted = false
    downloadFailed = false
    isPullingModel = false
    downloadProgress = 0.0
    statusMessage = ""
    errorMessage = ""
    currentDigest = ""
    searchText = ""
    isPopoverPresented = false
    selectedIndex = 0
  }
}

struct ModelPickerRow: View {
  let model: ChatModel
  let isSelected: Bool
  let isHighlighted: Bool

  var body: some View {
    HStack {
      Text(model.displayName)
        .foregroundColor(isHighlighted ? .white : .primary)

      Spacer()

      if isSelected {
        Image(systemName: "checkmark")
          .foregroundColor(isHighlighted ? .white : .accentColor)
      }
    }
    .padding(.vertical, 8)
    .padding(.horizontal, 4)
    .background(
      Group {
        if isHighlighted {
          Color.accentColor
        } else if isSelected {
          Color.accentColor.opacity(0.1)
        } else {
          Color.clear
        }
      }
    )
    .contentShape(Rectangle())
    .cornerRadius(4)
  }
}
