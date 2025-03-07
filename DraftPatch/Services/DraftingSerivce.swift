//
//  DraftingSerivce.swift
//  DraftPatch
//
//  Created by Robert DeLuca on 3/4/25.
//

import AppKit

@MainActor
final class DraftingSerivce: ObservableObject {
  static let shared = DraftingSerivce()
  @Published var hasAccessibilityPermission: Bool = false

  private init() {
    checkAccessibilityPermission()
  }

  /// Checks if the app has accessibility permissions and prompts if missing
  func checkAccessibilityPermission() {
    let checkOptions = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString
    let options = [checkOptions: true] as CFDictionary
    let isTrusted = AXIsProcessTrustedWithOptions(options)

    DispatchQueue.main.async {
      self.hasAccessibilityPermission = isTrusted
    }

    if !isTrusted {
      DispatchQueue.main.async {
        self.showAccessibilityAlert()
      }
    }
  }

  /// Displays an alert prompting the user to enable Accessibility Permissions
  private func showAccessibilityAlert() {
    let alert = NSAlert()
    alert.messageText = "Accessibility Permissions Required"
    alert.informativeText =
      "DraftPatch needs Accessibility permissions to read text from other applications. Please enable it in System Preferences."
    alert.alertStyle = .warning
    alert.addButton(withTitle: "Open System Preferences")
    alert.addButton(withTitle: "Cancel")

    let response = alert.runModal()
    if response == .alertFirstButtonReturn {
      openAccessibilityPreferences()
    }
  }

  /// Opens System Preferences to the Accessibility section
  private func openAccessibilityPreferences() {
    let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
    NSWorkspace.shared.open(url)
  }

  /// Returns the AXUIElement of a specified application by bundle identifier
  private func getApplicationElement(bundleIdentifier: String) -> AXUIElement? {
    let runningApps = NSWorkspace.shared.runningApplications
    guard let app = runningApps.first(where: { $0.bundleIdentifier == bundleIdentifier }) else {
      print("[AccessibilityTextService] \(bundleIdentifier) is not running.")
      return nil
    }

    print("[AccessibilityTextService] Found application: \(app.localizedName ?? bundleIdentifier).")
    return AXUIElementCreateApplication(app.processIdentifier)
  }

  /// Retrieves selected text or the full document text from a given application
  func getSelectedOrActiveText(appIdentifier: String) -> String {
    guard let appElement = getApplicationElement(bundleIdentifier: appIdentifier) else {
      return "[AccessibilityTextService] \(appIdentifier) is not running or not accessible."
    }

    print("[AccessibilityTextService] Searching for selected text in \(appIdentifier)...")

    // Try to get selected text from the focused UI element
    if let selectedText = getSelectedText(from: appElement) {
      print(
        "[AccessibilityTextService] Selected text found in \(appIdentifier): \(selectedText.prefix(100))...")
      return selectedText
    }

    // If no selection, try getting the full document text
    print(
      "[AccessibilityTextService] No selected text found, searching for full document text in \(appIdentifier)..."
    )
    if let documentText = getAttributeText(from: appElement, attribute: kAXValueAttribute as CFString) {
      print("[AccessibilityTextService] Found full document text in \(appIdentifier).")
      return documentText
    }

    print("[AccessibilityTextService] No text found in \(appIdentifier).")
    return "No text found."
  }

  /// Tries to get selected text from focused UI element (used for multiple applications)
  private func getSelectedText(from appElement: AXUIElement) -> String? {
    var focusedElement: AnyObject?
    if AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedElement)
      == .success
    {
      let focusedUIElement = focusedElement as! AXUIElement
      print("[AccessibilityTextService] Found focused UI element.")

      if let selectedText = getAttributeText(
        from: focusedUIElement, attribute: kAXSelectedTextAttribute as CFString)
      {
        print("[AccessibilityTextService] Found selected text.")
        return selectedText
      } else {
        print("[AccessibilityTextService] No selected text found in focused UI element.")
      }

      // If no selected text, check if it's a text area and get full document text
      if let role = getAttributeText(from: focusedUIElement, attribute: kAXRoleAttribute as CFString),
        role == "AXTextArea"
      {
        print("[AccessibilityTextService] Focused element is a text area. Trying to get full document text.")
        return getAttributeText(from: focusedUIElement, attribute: kAXValueAttribute as CFString)
      }
    } else {
      print("[AccessibilityTextService] Could not retrieve focused UI element.")
    }

    return nil
  }

  /// Helper function to get text from a given attribute
  private func getAttributeText(from element: AXUIElement, attribute: CFString) -> String? {
    var text: AnyObject?
    let result = AXUIElementCopyAttributeValue(element, attribute, &text)

    if result == .success {
      if let textString = text as? String {
        print("[AccessibilityTextService] Attribute \(attribute) found: \(textString.prefix(100))...")
        return textString
      } else {
        print("[AccessibilityTextService] Attribute \(attribute) found but is not a string.")
      }
    } else {
      print("[AccessibilityTextService] Failed to retrieve attribute \(attribute).")
    }

    return nil
  }

  /// Retrieves the current file extension by extracting it from the main window title using regex.
  func getCurrentFileExtension(appIdentifier: String) -> String? {
    guard let appElement = getApplicationElement(bundleIdentifier: appIdentifier) else {
      return nil
    }

    print("[AccessibilityTextService] Attempting to retrieve file extension from \(appIdentifier)...")

    // Try to get the document path first (only works for some apps)
    if let documentPath = getAttributeText(from: appElement, attribute: kAXDocumentAttribute as CFString) {
      let fileExtension = URL(fileURLWithPath: documentPath).pathExtension
      print("[AccessibilityTextService] Found document path: \(documentPath), extension: \(fileExtension)")
      return fileExtension.isEmpty ? nil : fileExtension
    }

    print("[AccessibilityTextService] No document path found. Trying main window title...")

    // Get the frontmost window element
    var windowElement: AnyObject?
    if AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowElement) == .success,
      let windowArray = windowElement as? [AXUIElement],
      let mainWindow = windowArray.first
    {

      // Extract the window title
      if let windowTitle = getAttributeText(from: mainWindow, attribute: kAXTitleAttribute as CFString) {
        print("[AccessibilityTextService] Found window title: \(windowTitle)")

        // Regex to find a valid filename with an extension
        let regex = try! NSRegularExpression(pattern: #"\b[\w,\s-]+\.[A-Za-z0-9]+(?=\b|\s)"#, options: [])
        let range = NSRange(location: 0, length: windowTitle.utf16.count)
        if let match = regex.firstMatch(in: windowTitle, options: [], range: range) {
          let matchedString = (windowTitle as NSString).substring(with: match.range)
          let fileExtension = URL(fileURLWithPath: matchedString).pathExtension
          print("[AccessibilityTextService] Extracted file extension: \(fileExtension)")
          return fileExtension.isEmpty ? nil : fileExtension
        }
      }
    }

    print("[AccessibilityTextService] No valid file extension found.")
    return nil
  }
}
