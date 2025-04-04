//
//  LLMService.swift
//  DraftPatch
//
//  Created by Robert DeLuca on 3/6/25.
//

import Foundation

protocol LLMService {
  // Base URL endpoint for API calls
  var endpointURL: URL { get }

  // Optional token or API key for authentication
  var apiKey: String? { get }

  var isCancelled: Bool { get set }

  // Fetch the list of available model names
  func fetchAvailableModels() async throws -> [String]

  // Perform a one-off chat completion with streaming
  func streamChat(
    messages: [ChatMessagePayload],
    modelName: String,
    model: ChatModel
  ) -> AsyncThrowingStream<String, Error>

  // Cancels the current streaming chat response
  func cancelStreamChat()

  // Perform a single chat completion, suitable for one-off requests (e.g., generating a title)
  func singleChatCompletion(
    message: String,
    modelName: String,
    model: ChatModel
  ) async throws -> String

  // Generate a chat title with the currently loaded/used LLM
  func generateTitle(
    for message: String,
    modelName: String,
    model: ChatModel
  ) async throws -> String
}

// Standardize message structure
struct ChatMessagePayload {
  let role: Role
  let content: String
}

extension LLMService {
  // Generate a title for the chat thread based on the user's first message
  func generateTitle(for message: String, modelName: String, model: ChatModel) async throws -> String {
    let prompt = """
      Summarize the following message into a short title (5 words or less). \
      Do not include quotes or punctuation. Only output the final short title. \
      Do not quote it. The output will be used for a conversation title.

      \(message)
      """

    let rawTitle = try await singleChatCompletion(message: prompt, modelName: modelName, model: model)

    let cleanedTitle =
      rawTitle
      .replacingOccurrences(of: "<think>[\\s\\S]*?</think>", with: "", options: .regularExpression)
      .replacingOccurrences(of: "[\"'.,!?;:]", with: "", options: .regularExpression)
      .trimmingCharacters(in: .whitespacesAndNewlines)

    return cleanedTitle
  }
}
