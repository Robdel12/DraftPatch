//
//  DraftPatchUITests.swift
//  DraftPatchUITests
//
//  Created by Robert DeLuca on 2/25/25.
//

import XCTest

final class DraftPatchUITests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  @MainActor
  func testCommandNCreatesNewChatThread() throws {
    let app = XCUIApplication()
    app.launchArguments.append("UI_TEST_MODE")
    app.launch()

    XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))

    app.typeKey("n", modifierFlags: .command)

    let newConversationTitle = app.staticTexts["New Conversation"]
    XCTAssertTrue(
      newConversationTitle.waitForExistence(timeout: 2), "The chat title is not 'New Conversation'")

    let noMessagesPlaceholder = app.staticTexts["No messages yet"]
    XCTAssertTrue(
      noMessagesPlaceholder.waitForExistence(timeout: 2),
      "Placeholder for no messages should exist in new conversation")
  }

  @MainActor
  func testAppLaunchShowsEmptyState() throws {
    let app = XCUIApplication()
    app.launchArguments.append("UI_TEST_MODE")
    app.launch()

    XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))

    let noChatSelectedText = app.staticTexts["No chat selected"]
    XCTAssertTrue(
      noChatSelectedText.waitForExistence(timeout: 2), "The 'No chat selected' text is not visible")

    let startDraftingText = app.staticTexts["Select a chat and start drafting!"]
    XCTAssertTrue(
      startDraftingText.waitForExistence(timeout: 2),
      "The 'Select a chat and start drafting!' text is not visible")

    let checkeredFlagImage = app.images["flag.checkered"]
    XCTAssertTrue(checkeredFlagImage.waitForExistence(timeout: 2), "The checkered flag image is not visible")
  }

  @MainActor
  func testCommandDShowsDraftingText() throws {
    let app = XCUIApplication()
    app.launchArguments.append("UI_TEST_MODE")
    app.launch()

    XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))

    app.typeKey("n", modifierFlags: .command)

    let title = app.staticTexts["New Conversation"]
    XCTAssertTrue(title.waitForExistence(timeout: 2), "The chat title is not 'New Conversation'")

    app.typeKey("d", modifierFlags: .command)

    let draftingTextElement = app.staticTexts["Drafting with Xcode • Unknown"]
    XCTAssertTrue(draftingTextElement.waitForExistence(timeout: 2), "The 'Drafting with' text did not appear")

    app.typeKey("d", modifierFlags: .command)
  }

  @MainActor
  func testSendingChatMessage() throws {
    let app = XCUIApplication()
    app.launchArguments.append("UI_TEST_MODE")
    app.launch()

    XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))

    app.typeKey("n", modifierFlags: .command)

    let title = app.staticTexts["New Conversation"]
    XCTAssertTrue(title.waitForExistence(timeout: 2), "The chat title is not 'New Conversation'")

    let messageField = app.textFields["Chatbox"]
    XCTAssertTrue(messageField.waitForExistence(timeout: 2), "Chat input field is not visible")

    let messageText = "Hello, how are you?"
    messageField.tap()
    messageField.typeText(messageText)
    app.typeKey(.return, modifierFlags: [])

    let sentMessage = app.staticTexts[messageText]
    XCTAssertTrue(sentMessage.waitForExistence(timeout: 2), "Sent message is not visible")

    let fullMessage =
      "Hello world! How are you doing today? This is a mocked response from a large language model. Hope this helps!"
    let replyMessage = app.staticTexts[fullMessage]

    XCTAssertTrue(replyMessage.waitForExistence(timeout: 5), "AI reply is not visible")
    XCTAssertTrue(replyMessage.frame.minY > sentMessage.frame.minY, "Reply should be below the sent message")
  }

  @MainActor
  func testRenamingChatThread() throws {
    let app = XCUIApplication()
    app.launchArguments.append("UI_TEST_MODE")
    app.launch()

    XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))

    app.typeKey("n", modifierFlags: .command)

    let title = app.staticTexts["New Conversation"]
    XCTAssertTrue(title.waitForExistence(timeout: 2), "The chat title is not 'New Conversation'")

    let messageField = app.textFields["Chatbox"]
    XCTAssertTrue(messageField.waitForExistence(timeout: 2), "Chat input field is not visible")

    let messageText = "Hello, how are you?"
    messageField.tap()
    messageField.typeText(messageText)
    app.typeKey(.return, modifierFlags: [])

    let sentMessage = app.staticTexts[messageText]
    XCTAssertTrue(sentMessage.waitForExistence(timeout: 2), "Sent message is not visible")

    let threadTitle = app.staticTexts["Mock Title"]
    XCTAssertTrue(threadTitle.waitForExistence(timeout: 2), "The thread title is not visible")
    threadTitle.doubleTap()

    let renameField = app.textFields["renameThreadTextField"]
    XCTAssertTrue(renameField.waitForExistence(timeout: 2), "Rename thread text field is not visible")
    let newTitle = "Renamed Thread"
    renameField.tap()
    renameField.typeKey("a", modifierFlags: .command)
    renameField.typeKey(.delete, modifierFlags: [])
    renameField.typeText(newTitle)
    app.typeKey(.return, modifierFlags: [])

    let updatedThreadTitle = app.staticTexts[newTitle]
    XCTAssertTrue(updatedThreadTitle.waitForExistence(timeout: 2), "The thread title was not updated")
  }

  @MainActor
  func testSelectingModelFromPopover() throws {
    let app = XCUIApplication()
    app.launchArguments.append("UI_TEST_MODE")
    app.launch()

    XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))

    let defaultSelectedModel = app.buttons["ModelSelectorButton"].firstMatch
    XCTAssertTrue(defaultSelectedModel.waitForExistence(timeout: 2), "Can't find the default model")
    XCTAssertEqual(defaultSelectedModel.label, "Default", "The selected model does not equal the default")

    app.typeKey("e", modifierFlags: .command)

    let searchField = app.textFields["ModelSearchField"]
    XCTAssertTrue(searchField.waitForExistence(timeout: 2), "Model search field is not visible")

    searchField.tap()
    searchField.typeText("MockModel2")

    let modelOption = app.staticTexts["MockModel2"]
    XCTAssertTrue(modelOption.waitForExistence(timeout: 2), "MockModel2 option is not visible")

    modelOption.tap()

    let selectedModelButton = app.buttons["ModelSelectorButton"].firstMatch
    XCTAssertTrue(selectedModelButton.waitForExistence(timeout: 2), "Model selector button is not visible")
    XCTAssertEqual(selectedModelButton.label, "MockModel2", "The selected model did not update to MockModel2")
  }

  @MainActor
  func testCreatingSendingSelectingAndDeletingChatThread() throws {
    let app = XCUIApplication()
    app.launchArguments.append("UI_TEST_MODE")
    app.launch()

    XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))

    // Create a new chat thread
    app.typeKey("n", modifierFlags: .command)

    let title = app.staticTexts["New Conversation"]
    XCTAssertTrue(title.waitForExistence(timeout: 2), "The chat title is not 'New Conversation'")

    // Send a new chat message
    let messageField = app.textFields["Chatbox"]
    XCTAssertTrue(messageField.waitForExistence(timeout: 2), "Chat input field is not visible")

    let messageText = "Test message"
    messageField.tap()
    messageField.typeText(messageText)
    app.typeKey(.return, modifierFlags: [])

    let sentMessage = app.staticTexts[messageText]
    XCTAssertTrue(sentMessage.waitForExistence(timeout: 2), "Sent message is not visible")

    let sidebarToggle = app.buttons["Show Sidebar"].firstMatch
    if sidebarToggle.exists {
      sidebarToggle.tap()
    }

    // Select chat thread from sidebar
    let chatThread = app.buttons["ChatThread_Mock Title"]
    XCTAssertTrue(chatThread.waitForExistence(timeout: 2), "New conversation is not visible in sidebar")
    chatThread.tap()

    // Right-click to open context menu
    chatThread.rightClick()

    let deleteButton = app.menuItems["DeleteChatThread_Mock Title"]
    XCTAssertTrue(deleteButton.waitForExistence(timeout: 2), "Delete option is not visible in context menu")

    // Delete the thread
    deleteButton.tap()

    XCTAssertFalse(chatThread.waitForExistence(timeout: 2), "Chat thread was not deleted")
  }

  @MainActor
  func testSelectingDraftingApp() throws {
    let app = XCUIApplication()
    app.launchArguments.append("UI_TEST_MODE")
    app.launch()

    XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))

    app.typeKey("n", modifierFlags: .command)

    let title = app.staticTexts["New Conversation"]
    XCTAssertTrue(title.waitForExistence(timeout: 2), "The chat title is not 'New Conversation'")

    let draftingOptionsButton = app.buttons["Open Drafting Options"]
    XCTAssertTrue(
      draftingOptionsButton.waitForExistence(timeout: 2), "Drafting options button is not visible")

    draftingOptionsButton.tap()

    let xcodeOption = app.buttons["Draft with Xcode"]
    XCTAssertTrue(
      xcodeOption.waitForExistence(timeout: 2), "Draft with Xcode button is not visible in the popover")

    xcodeOption.tap()

    let draftingText = app.staticTexts["Drafting with Xcode • Unknown"]
    XCTAssertTrue(
      draftingText.waitForExistence(timeout: 2),
      "The drafting text did not update to 'Drafting with Xcode • Unknown'")
  }

  @MainActor
  func testStoppingMessageBeforeCompletion() throws {
    let app = XCUIApplication()
    app.launchArguments.append("UI_TEST_MODE")
    app.launch()

    XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))

    app.typeKey("n", modifierFlags: .command)

    let title = app.staticTexts["New Conversation"]
    XCTAssertTrue(title.waitForExistence(timeout: 2), "The chat title is not 'New Conversation'")

    let messageField = app.textFields["Chatbox"]
    XCTAssertTrue(messageField.waitForExistence(timeout: 2), "Chat input field is not visible")

    let messageText = "Hello!"
    messageField.tap()
    messageField.typeText(messageText)
    app.typeKey(.return, modifierFlags: [])

    let stopButton = app.buttons["Stop"]
    XCTAssertTrue(stopButton.waitForExistence(timeout: 2), "Stop button is not visible")
    stopButton.tap()

    let fullMessage =
      "Hello world! How are you doing today? This is a mocked response from a large language model. Hope this helps!"
    let truncatedMessage = app.staticTexts[fullMessage]
    XCTAssertFalse(truncatedMessage.exists, "The full response message was printed even after stopping")
  }
}
