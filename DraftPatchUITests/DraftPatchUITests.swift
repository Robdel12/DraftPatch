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

  //  @MainActor
  //  func testLaunchPerformance() throws {
  //    if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
  //      // This measures how long it takes to launch your application.
  //      measure(metrics: [XCTApplicationLaunchMetric()]) {
  //        XCUIApplication().launch()
  //      }
  //    }
  //  }

  @MainActor
  func testCommandNCreatesNewChatThread() throws {
    let app = XCUIApplication()
    app.launchArguments.append("UI_TEST_MODE")
    app.launch()

    XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))

    app.typeKey("n", modifierFlags: .command)

    // Optionally, ensure new thread is selected
     app.typeKey("d", modifierFlags: .command)

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

    // Create a new chat using Command + N
    app.typeKey("n", modifierFlags: .command)

    let title = app.staticTexts["New Conversation"]
    XCTAssertTrue(title.waitForExistence(timeout: 2), "The chat title is not 'New Conversation'")

    // Press Command + D
    app.typeKey("d", modifierFlags: .command)

    // Verify "Drafting with" text appears
    let draftingTextElement = app.staticTexts["Drafting with Xcode • Unknown"]
    XCTAssertTrue(draftingTextElement.waitForExistence(timeout: 2), "The 'Drafting with' text did not appear")

    app.typeKey("d", modifierFlags: .command)
  }
}
