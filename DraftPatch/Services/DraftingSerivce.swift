//
//  DraftingSerivce.swift
//  DraftPatch
//
//  Created by Robert DeLuca on 3/4/25.
//

import AppKit

@MainActor
final class DraftingService: ObservableObject {
  static let shared = DraftingService()
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

  /// Retrieves selected text or falls back to getting the full view content
  func getSelectedOrViewText(appIdentifier: String) -> String {
    guard let appElement = getApplicationElement(bundleIdentifier: appIdentifier) else {
      return "[AccessibilityTextService] \(appIdentifier) is not running or not accessible."
    }

    print("[AccessibilityTextService] Searching for selected text in \(appIdentifier)...")

    // Try to get selected text
    if let selectedText = getSelectedText(from: appElement), !selectedText.isEmpty {
      print(
        "[AccessibilityTextService] Selected text found in \(appIdentifier): \(selectedText.prefix(100))...")
      return selectedText
    }

    print(
      "[AccessibilityTextService] No selected text found or selected text is empty, retrieving full view content..."
    )

    // If no selection, get the entire view's content
    if let viewText = getViewContent(from: appElement), !viewText.isEmpty {
      print("[AccessibilityTextService] Found full view content in \(appIdentifier).")
      return viewText
    }

    print("[AccessibilityTextService] No text found in \(appIdentifier).")
    return "No text found."
  }

  /// Retrieves the full contents of the current application's focused view
  private func getViewContent(from appElement: AXUIElement) -> String? {
    var focusedElement: AnyObject?
    if AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedElement)
      == .success
    {
      let focusedUIElement = focusedElement as! AXUIElement
      print("[AccessibilityTextService] Found focused UI element.")

      // Attempt to get full text content of the view
      if let fullText = getAttributeText(from: focusedUIElement, attribute: kAXValueAttribute as CFString) {
        print("[AccessibilityTextService] Retrieved full text from view.")
        return fullText
      } else {
        print("[AccessibilityTextService] Unable to retrieve full view content.")
      }
    } else {
      print("[AccessibilityTextService] Could not retrieve focused UI element.")
    }

    return nil
  }

  // Retrieves selected text details, including line numbers and file name
  func getSelectedTextDetails(appIdentifier: String) -> (
    text: String?, lines: (start: Int, end: Int)?, fileName: String?
  ) {
    guard let appElement = getApplicationElement(bundleIdentifier: appIdentifier) else {
      return (nil, nil, nil)
    }

    print("[AccessibilityTextService] Retrieving selected text details from \(appIdentifier)...")

    // Get the full document text for line number calculations
    let fullText = getViewContent(from: appElement)

    // Get the selected text
    var focusedElement: AnyObject?
    guard
      AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedElement)
        == .success
    else {
      print("[AccessibilityTextService] Could not retrieve focused UI element.")
      return (nil, nil, getCurrentFileName(appIdentifier: appIdentifier))
    }

    let focusedUIElement = focusedElement as! AXUIElement

    guard
      let selectedText = getAttributeText(
        from: focusedUIElement, attribute: kAXSelectedTextAttribute as CFString),
      !selectedText.isEmpty
    else {
      print("[AccessibilityTextService] No selected text found.")
      return (nil, nil, getCurrentFileName(appIdentifier: appIdentifier))
    }

    // Get selected text range, passing in full text for fallback
    guard let selectedRange = getSelectedTextRange(from: appElement, fullText: fullText) else {
      print("[AccessibilityTextService] Unable to determine selected text range.")
      return (selectedText, nil, getCurrentFileName(appIdentifier: appIdentifier))
    }

    // Compute line numbers
    let lineNumbers = fullText != nil ? computeLineNumbers(from: fullText!, range: selectedRange) : nil

    return (selectedText, lineNumbers, getCurrentFileName(appIdentifier: appIdentifier))
  }

  /// Gets the selected text range as a tuple (start, length)
  private func getSelectedTextRange(from appElement: AXUIElement, fullText: String?) -> (
    start: Int, length: Int
  )? {
    // First, get the focused UI element
    var focusedElement: AnyObject?
    if AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedElement)
      != .success
    {
      print("[AccessibilityTextService] Could not retrieve focused UI element.")
      return nil
    }

    let focusedUIElement = focusedElement as! AXUIElement

    // Try to get the selection range directly
    var rangeValue: AnyObject?
    let result = AXUIElementCopyAttributeValue(
      focusedUIElement, kAXSelectedTextRangeAttribute as CFString, &rangeValue)

    if result == .success, let range = rangeValue as? CFRange {
      print(
        "[AccessibilityTextService] Successfully retrieved selected text range: \(range.location)-\(range.location + range.length)"
      )
      return (Int(range.location), Int(range.length))
    } else {
      print(
        "[AccessibilityTextService] Failed to retrieve AXSelectedTextRangeAttribute, attempting alternative methods..."
      )
    }

    // Alternative method 1: Try to get the selection range as a value instead of a CFRange
    if let selectedRangeStr = getAttributeText(
      from: focusedUIElement, attribute: kAXSelectedTextRangeAttribute as CFString)
    {
      print("[AccessibilityTextService] Got selection range as string: \(selectedRangeStr)")
      // Parse the range string if in a known format
      // Format might be like "{123, 45}" depending on the app
      let cleaned = selectedRangeStr.trimmingCharacters(in: CharacterSet(charactersIn: "{}"))
      let components = cleaned.components(separatedBy: ",")
      if components.count == 2,
        let start = Int(components[0].trimmingCharacters(in: .whitespaces)),
        let length = Int(components[1].trimmingCharacters(in: .whitespaces))
      {
        return (start, length)
      }
    }

    // Alternative method 2: Infer range from full text and selected text
    if let fullText = fullText,
      let selectedText = getAttributeText(
        from: focusedUIElement, attribute: kAXSelectedTextAttribute as CFString),
      !selectedText.isEmpty
    {

      // If we have the visible range attribute, use it to constrain our search
      var visibleRange: (start: Int, length: Int)?
      var visibleRangeValue: AnyObject?
      if AXUIElementCopyAttributeValue(
        focusedUIElement, kAXVisibleCharacterRangeAttribute as CFString, &visibleRangeValue) == .success,
        let vRange = visibleRangeValue as? CFRange
      {
        visibleRange = (Int(vRange.location), Int(vRange.length))
      }

      // Check if we can find the selection in the visible range first, then the full document
      if let range = findSelectionRange(in: fullText, selectedText: selectedText, visibleRange: visibleRange)
      {
        print(
          "[AccessibilityTextService] Computed selection range from text: \(range.start)-\(range.start + range.length)"
        )
        return range
      }
    }

    print("[AccessibilityTextService] Unable to determine selected text range.")
    return nil
  }

  /// Helper function to find the selection range in text
  private func findSelectionRange(
    in fullText: String, selectedText: String, visibleRange: (start: Int, length: Int)?
  ) -> (start: Int, length: Int)? {
    // If we know the visible range, try to find the selection within that range first
    if let visibleRange = visibleRange {
      let visibleStartIndex = fullText.index(
        fullText.startIndex, offsetBy: min(visibleRange.start, fullText.count - 1))
      let visibleEndIndex = fullText.index(
        visibleStartIndex,
        offsetBy: min(
          visibleRange.length,
          fullText.count - fullText.distance(from: fullText.startIndex, to: visibleStartIndex) - 1))
      let visibleText = fullText[visibleStartIndex..<visibleEndIndex]

      if let range = visibleText.range(of: selectedText) {
        let start = fullText.distance(from: fullText.startIndex, to: range.lowerBound) + visibleRange.start
        let length = selectedText.count
        return (start, length)
      }
    }

    // Search in the entire document
    if let range = fullText.range(of: selectedText) {
      let start = fullText.distance(from: fullText.startIndex, to: range.lowerBound)
      let length = selectedText.count
      return (start, length)
    }

    // If the text contains newlines or special characters, they might be represented differently
    // Try a fuzzy match as a last resort
    if selectedText.count > 10 {  // Only try this for substantial selections to avoid false positives
      // Create a simplified version of both texts (removing extra whitespace)
      let simplifiedFullText = fullText.replacingOccurrences(
        of: "\\s+", with: " ", options: .regularExpression)
      let simplifiedSelection = selectedText.replacingOccurrences(
        of: "\\s+", with: " ", options: .regularExpression)

      if let range = simplifiedFullText.range(of: simplifiedSelection) {
        // This is approximate, but better than nothing
        let approxStart = simplifiedFullText.distance(
          from: simplifiedFullText.startIndex, to: range.lowerBound)
        return (approxStart, selectedText.count)
      }
    }

    return nil
  }

  /// Improved line number calculation
  private func computeLineNumbers(from fullText: String, range: (start: Int, length: Int)) -> (
    start: Int, end: Int
  )? {
    // Ensure the range is valid
    guard range.start >= 0, range.length >= 0, range.start + range.length <= fullText.count else {
      print("[AccessibilityTextService] Invalid range for line number calculation")
      return nil
    }

    // Convert string indices to integer offsets for easier calculation
    let startIndex = fullText.index(fullText.startIndex, offsetBy: range.start)
    let endIndex = fullText.index(startIndex, offsetBy: range.length)

    // Count newlines before selection start to determine start line
    let textBeforeSelection = fullText[..<startIndex]
    let startLine = textBeforeSelection.components(separatedBy: "\n").count

    // If selection spans multiple lines, count newlines within selection
    if range.length > 0 {
      let selectedText = fullText[startIndex..<endIndex]
      let linesInSelection = selectedText.components(separatedBy: "\n").count - 1
      let endLine = startLine + linesInSelection
      return (startLine, endLine)
    } else {
      return (startLine, startLine)
    }
  }

  /// Retrieves the current file name from the application window title
  private func getCurrentFileName(appIdentifier: String) -> String? {
    guard let appElement = getApplicationElement(bundleIdentifier: appIdentifier) else {
      return nil
    }

    print("[AccessibilityTextService] Attempting to retrieve file name from \(appIdentifier)...")

    // Try to get document path first
    if let documentPath = getAttributeText(from: appElement, attribute: kAXDocumentAttribute as CFString) {
      let fileName = URL(fileURLWithPath: documentPath).lastPathComponent
      print("[AccessibilityTextService] Found document path: \(documentPath), file: \(fileName)")
      return fileName
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

        // Extract the file name from the title
        let regex = try! NSRegularExpression(pattern: #"\b[\w,\s-]+\.[A-Za-z0-9]+(?=\b|\s)"#, options: [])
        let range = NSRange(location: 0, length: windowTitle.utf16.count)
        if let match = regex.firstMatch(in: windowTitle, options: [], range: range) {
          let matchedString = (windowTitle as NSString).substring(with: match.range)
          let fileName = URL(fileURLWithPath: matchedString).lastPathComponent
          print("[AccessibilityTextService] Extracted file name: \(fileName)")
          return fileName
        }
      }
    }

    print("[AccessibilityTextService] No valid file name found.")
    return nil
  }
}
