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

  var filteredModels: [ChatModel] {
    if searchText.isEmpty {
      return viewModel.availableModels
    } else {
      return viewModel.availableModels.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
  }

  var canDownloadNewModel: Bool {
    !searchText.isEmpty
      && !viewModel.availableModels.contains(where: { $0.name.localizedCaseInsensitiveContains(searchText) })
  }

  var body: some View {
    Button {
      isPopoverPresented.toggle()
    } label: {
      HStack {
        Text(viewModel.selectedModel.name)
        Image(systemName: "chevron.down")
      }
      .padding(8)
      .contentShape(Rectangle())
    }
    .keyboardShortcut("e", modifiers: .command)
    .buttonStyle(.plain)
    .background(
      RoundedRectangle(cornerRadius: 8)
        .stroke(Color.gray, lineWidth: 2)
    )
    .popover(isPresented: $isPopoverPresented) {
      VStack(alignment: .leading, spacing: 12) {
        Text("Select Model")
          .font(.headline)

        HStack {
          Image(systemName: "magnifyingglass")
            .foregroundColor(.secondary)
          TextField("Search or download a model", text: $searchText)
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .focused($isSearchFieldFocused)
            .onAppear {
              isSearchFieldFocused = true
              selectedIndex = 0
            }
            .onSubmit {
              if !filteredModels.isEmpty {
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

        Divider()

        ScrollView {
          LazyVStack(alignment: .leading, spacing: 4) {
            if filteredModels.isEmpty && !canDownloadNewModel {
              Text("No matching models found")
                .foregroundColor(.secondary)
                .padding(.vertical, 8)
            } else {
              ForEach(Array(filteredModels.enumerated()), id: \.element.id) { index, model in
                ModelPickerRow(
                  model: model,
                  isSelected: model.id == viewModel.selectedModel.id,
                  isHighlighted: selectedIndex == index
                )
                .id(index)
                .onTapGesture {
                  selectModel(at: index)
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

              if canDownloadNewModel {
                if !filteredModels.isEmpty {
                  Divider()
                    .padding(.vertical, 4)
                }

                if isPullingModel {
                  VStack(alignment: .leading, spacing: 8) {
                    Text(statusMessage)
                      .foregroundColor(.secondary)

                    ProgressView(value: downloadProgress)
                      .progressViewStyle(LinearProgressViewStyle())
                  }
                  .padding(.vertical, 8)
                } else if downloadCompleted {
                  HStack {
                    Image(systemName: "checkmark.circle.fill")
                      .foregroundColor(.green)
                    Text("Download complete!")
                      .foregroundColor(.green)
                  }
                  .padding(.vertical, 8)
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
                  .padding(.vertical, 8)
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
                    .padding(.vertical, 8)
                  }
                  .buttonStyle(PlainButtonStyle())
                  .background(
                    selectedIndex == filteredModels.count ? Color.accentColor.opacity(0.1) : Color.clear
                  )
                  .cornerRadius(4)
                  .id(filteredModels.count)
                }
              }
            }
          }
        }
        .frame(height: min(350, CGFloat(filteredModels.count * 40 + (canDownloadNewModel ? 60 : 0))))
      }
      .padding()
      .frame(width: 300)
      .onChange(of: downloadCompleted) { _, completed in
        if completed {
          DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            let newModel = ChatModel(name: searchText, provider: .ollama)
            viewModel.availableModels.append(newModel)
            viewModel.selectedModel = newModel

            // Reset states
            downloadCompleted = false
            searchText = ""
            isPopoverPresented = false

            Task {
              await viewModel.loadOllamaModels()
            }
          }
        }
      }
      .onChange(of: filteredModels.count) { _, newCount in
        if selectedIndex >= newCount {
          selectedIndex = newCount > 0 ? newCount - 1 : 0
        }
      }
      .onChange(of: searchText) { _, _ in
        selectedIndex = 0
      }
    }
  }

  private func navigateUp() {
    if selectedIndex > 0 {
      selectedIndex -= 1
    } else if canDownloadNewModel && filteredModels.count > 0 {
      selectedIndex = filteredModels.count
    }
  }

  private func navigateDown() {
    let maxIndex = canDownloadNewModel ? filteredModels.count : filteredModels.count - 1
    if selectedIndex < maxIndex {
      selectedIndex += 1
    } else {
      selectedIndex = 0
    }
  }

  private func selectModel(at index: Int) {
    if index < filteredModels.count {
      viewModel.selectedModel = filteredModels[index]
      isPopoverPresented = false
    }
  }

  private func deleteModel(modelName: String) {
    Task {
      do {
        try await OllamaService.shared.deleteModel(modelName: modelName)
        viewModel.availableModels.removeAll { $0.name == modelName }
        if let firstAvailable = viewModel.availableModels.first, viewModel.selectedModel.name == modelName {
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
      }
    }
  }

  private func formatSize(bytes: Int64) -> String {
    let formatter = ByteCountFormatter()
    formatter.allowedUnits = [.useKB, .useMB, .useGB]
    formatter.countStyle = .file
    return formatter.string(fromByteCount: bytes)
  }
}

struct ModelPickerRow: View {
  let model: ChatModel
  let isSelected: Bool
  let isHighlighted: Bool

  var body: some View {
    HStack {
      Text(model.name)
        .foregroundColor(isSelected ? .white : .primary)

      Spacer()

      if isSelected {
        Image(systemName: "checkmark")
          .foregroundColor(.accentColor)
      }
    }
    .padding(.vertical, 8)
    .padding(.horizontal, 4)
    .background(
      Group {
        if isHighlighted {
          Color.accentColor.opacity(0.2)
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
