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
    }
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
        }

        Divider()

        ScrollView {
          LazyVStack(alignment: .leading, spacing: 4) {
            if filteredModels.isEmpty && !canDownloadNewModel {
              Text("No matching models found")
                .foregroundColor(.secondary)
                .padding(.vertical, 8)
            } else {
              ForEach(filteredModels, id: \.id) { model in
                ModelPickerRow(
                  model: model,
                  isSelected: model.id == viewModel.selectedModel.id
                )
                .contextMenu {
                  if model.provider == .ollama {
                    Button(role: .destructive) {
                      deleteModel(modelName: model.name)
                    } label: {
                      Text("Delete")
                    }
                  }
                }
                .onTapGesture {
                  viewModel.selectedModel = model
                  isPopoverPresented = false
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

  var body: some View {
    HStack {
      Text(model.name)
        .foregroundColor(isSelected ? .accentColor : .primary)

      Spacer()

      if isSelected {
        Image(systemName: "checkmark")
          .foregroundColor(.accentColor)
      }
    }
    .padding(.vertical, 8)
    .padding(.horizontal, 4)
    .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
    .cornerRadius(4)
  }
}
