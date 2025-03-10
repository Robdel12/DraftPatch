//
//  OllamaModelManagementView.swift
//  DraftPatch
//
//  Created by Robert DeLuca on 3/10/25.
//

import SwiftUI

struct OllamaModelManagementView: View {
  @State private var modelName: String = ""
  @State private var statusMessage: String = ""
  @State private var downloadProgress: Double = 0.0
  @State private var isPullingModel: Bool = false
  @State private var downloadCompleted: Bool = false
  @State private var downloadFailed: Bool = false
  @State private var errorMessage: String = ""
  @State private var currentDigest: String = ""

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Download Ollama Model")
        .font(.headline)
        .padding(.bottom, 4)

      HStack(spacing: 12) {
        TextField("Enter model name (e.g., llama3)", text: $modelName)
          .textFieldStyle(RoundedBorderTextFieldStyle())
          .disabled(isPullingModel)

        Button(action: pullModel) {
          Text("Download")
            .frame(minWidth: 80)
        }
        .buttonStyle(.borderedProminent)
        .disabled(isPullingModel || modelName.isEmpty)
      }

      if isPullingModel {
        VStack(alignment: .leading, spacing: 8) {
          HStack {
            ProgressView(value: downloadProgress, total: 1.0)
              .progressViewStyle(.linear)

            Text("\(Int(downloadProgress * 100))%")
              .font(.caption)
              .frame(width: 40, alignment: .trailing)
          }

          Text(statusMessage)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
        .transition(.opacity)
      }

      if downloadCompleted {
        HStack {
          Image(systemName: "checkmark.circle.fill")
            .foregroundStyle(.green)
          Text("Successfully downloaded \(modelName)")
            .foregroundStyle(.secondary)
        }
        .padding(.top, 4)
        .transition(.opacity)
      }

      if downloadFailed {
        VStack(alignment: .leading, spacing: 4) {
          HStack {
            Image(systemName: "exclamationmark.circle.fill")
              .foregroundStyle(.red)
            Text("Download failed")
              .foregroundStyle(.secondary)
          }
          Text(errorMessage)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.top, 4)
        .transition(.opacity)
      }

      Spacer()
    }
    .padding()
    .animation(.easeInOut, value: isPullingModel)
    .animation(.easeInOut, value: downloadCompleted)
    .animation(.easeInOut, value: downloadFailed)
  }

  private func pullModel() {
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
            print("Received JSON: \(json)")

            if let status = json["status"] as? String {
              statusMessage = status

              if status == "success" {
                downloadProgress = 1.0
                isPullingModel = false
                downloadCompleted = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                  modelName = ""
                }
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
          DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            modelName = ""
          }
        }
      }
    }
  }

  // Helper function to format file sizes
  private func formatSize(bytes: Int64) -> String {
    let formatter = ByteCountFormatter()
    formatter.allowedUnits = [.useGB, .useMB]
    formatter.countStyle = .file
    return formatter.string(fromByteCount: bytes)
  }
}
