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
    guard
      AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedElement)
        == .success,
      let element = focusedElement,  // Ensure not nil first
      CFGetTypeID(element) == AXUIElementGetTypeID()  // Check the CoreFoundation type ID
    else {
      print("[AccessibilityTextService] Could not retrieve focused UI element or it's not an AXUIElement.")
      return nil
    }
    let focusedUIElement = element as! AXUIElement  // Cast after type check

    print("[AccessibilityTextService] Found focused UI element.")

    if let selectedText = getAttributeText(
      from: focusedUIElement,
      attribute: kAXSelectedTextAttribute as CFString
    ) {
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

    // Removed the else block here as the function returns nil at the end anyway if nothing is found

    return nil
  }

  /// Helper function to get text from a given attribute
  private func getAttributeText(from element: AXUIElement, attribute: CFString) -> String? {
    var value: AnyObject?
    let result = AXUIElementCopyAttributeValue(element, attribute, &value)

    guard result == .success, let retrievedValue = value else {
      print("[AccessibilityTextService] Failed to retrieve attribute \(attribute). Error: \(result.rawValue)")
      return nil
    }

    // Check if the value is already a String
    if let textString = retrievedValue as? String {
      print(
        "[AccessibilityTextService] Attribute \(attribute) retrieved directly as String: \(textString.prefix(100))..."
      )
      return textString
    }

    // Check if the value can be interpreted as Data and decoded as UTF-8
    // Sometimes accessibility might return CFDataRef instead of CFStringRef
    if CFGetTypeID(retrievedValue) == CFDataGetTypeID() {
      if let data = retrievedValue as? Data, let textString = String(data: data, encoding: .utf8) {
        print(
          "[AccessibilityTextService] Attribute \(attribute) retrieved as Data and decoded as UTF-8: \(textString.prefix(100))..."
        )
        return textString
      } else {
        print(
          "[AccessibilityTextService] Attribute \(attribute) retrieved as Data but failed to decode as UTF-8."
        )
      }
    }

    // Fallback check for other potential types if necessary, though String and Data cover most cases.
    // For example, sometimes it might be an NSAttributedString
    if let attributedString = retrievedValue as? NSAttributedString {
      print(
        "[AccessibilityTextService] Attribute \(attribute) retrieved as NSAttributedString, using its string value: \(attributedString.string.prefix(100))..."
      )
      return attributedString.string
    }

    print(
      "[AccessibilityTextService] Attribute \(attribute) found but is not a recognizable String or decodable Data type. Type: \(type(of: retrievedValue))"
    )
    return nil
  }

  /// Retrieves the current file extension by extracting it from the main window title using regex.
  func getCurrentFileExtension(appIdentifier: String) -> String? {
    guard let appElement = getApplicationElement(bundleIdentifier: appIdentifier) else {
      return nil
    }

    print("[AccessibilityTextService] Attempting to retrieve file extension from \(appIdentifier)...")

    // Try to get the document path first
    if let documentPath = getAttributeText(from: appElement, attribute: kAXDocumentAttribute as CFString) {
      let url = URL(fileURLWithPath: documentPath)
      // Ensure path extension is not empty before returning
      if !url.pathExtension.isEmpty {
        print(
          "[AccessibilityTextService] Found document path: \(documentPath), extension: \(url.pathExtension)"
        )
        return url.pathExtension
      }
    }

    print("[AccessibilityTextService] No document path found or extension empty. Trying main window title...")

    // Use helper to get title and extract extension
    if let windowTitle = getMainWindowTitle(from: appElement),
      let fileName = extractFileNameFromTitle(windowTitle)
    {
      let fileExtension = URL(fileURLWithPath: fileName).pathExtension
      if !fileExtension.isEmpty {
        print("[AccessibilityTextService] Extracted file extension from title: \(fileExtension)")
        return fileExtension
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
        "[AccessibilityTextService] Selected text found in \(appIdentifier): \(selectedText.prefix(100))..."
      )
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
    guard
      AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedElement)
        == .success,
      let element = focusedElement,  // Ensure not nil first
      CFGetTypeID(element) == AXUIElementGetTypeID()  // Check the CoreFoundation type ID
    else {
      print("[AccessibilityTextService] Could not retrieve focused UI element or it's not an AXUIElement.")
      return nil
    }
    let focusedUIElement = element as! AXUIElement  // Cast after type check

    print("[AccessibilityTextService] Found focused UI element.")

    // Attempt to get full text content of the view
    if let fullText = getAttributeText(from: focusedUIElement, attribute: kAXValueAttribute as CFString) {
      print("[AccessibilityTextService] Retrieved full text from view.")
      return fullText
    } else {
      print("[AccessibilityTextService] Unable to retrieve full view content.")
      return nil  // Explicitly return nil
    }

    // Removed the else block here as the function returns nil if attribute retrieval fails
  }

  // Retrieves selected text details, including line numbers and file name
  func getSelectedTextDetails(appIdentifier: String) -> (
    text: String?, lines: (start: Int, end: Int)?, fileName: String?
  ) {
    guard let appElement = getApplicationElement(bundleIdentifier: appIdentifier) else {
      return (nil, nil, nil)
    }

    let currentFileName = getCurrentFileName(appIdentifier: appIdentifier)  // Get filename early

    print("[AccessibilityTextService] Retrieving selected text details from \(appIdentifier)...")

    // Get the full document text for line number calculations
    let fullText = getViewContent(from: appElement)

    // Get the focused UI element
    var focusedElement: AnyObject?
    guard
      AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedElement)
        == .success,
      let element = focusedElement,  // Ensure not nil first
      CFGetTypeID(element) == AXUIElementGetTypeID()  // Check the CoreFoundation type ID
    else {
      print("[AccessibilityTextService] Could not retrieve focused UI element or it's not an AXUIElement.")
      return (nil, nil, currentFileName)  // Return filename even if no selection
    }
    let focusedUIElement = element as! AXUIElement  // Cast after type check

    // Get the selected text
    guard
      let selectedText = getAttributeText(
        from: focusedUIElement,
        attribute: kAXSelectedTextAttribute as CFString
      ),
      !selectedText.isEmpty
    else {
      print("[AccessibilityTextService] No selected text found.")
      return (nil, nil, currentFileName)  // Return filename even if no selection
    }

    // Get selected text range, passing in full text for fallback
    // Pass focusedUIElement directly instead of appElement to getSelectedTextRange
    guard let selectedRange = getSelectedTextRange(from: focusedUIElement, fullText: fullText) else {
      print("[AccessibilityTextService] Unable to determine selected text range.")
      return (selectedText, nil, currentFileName)
    }

    // Compute line numbers
    let lineNumbers = fullText != nil ? computeLineNumbers(from: fullText!, range: selectedRange) : nil

    return (selectedText, lineNumbers, currentFileName)
  }

  /// Gets the selected text range as a tuple (start, length)
  // Changed parameter from appElement to focusedUIElement for clarity and directness
  private func getSelectedTextRange(from focusedUIElement: AXUIElement, fullText: String?) -> (
    start: Int, length: Int
  )? {
    // No need to get focused element again, it's passed in

    // Try to get the selection range directly
    var rangeValue: AnyObject?
    let result = AXUIElementCopyAttributeValue(
      focusedUIElement,
      kAXSelectedTextRangeAttribute as CFString,
      &rangeValue
    )

    if result == .success, let range = rangeValue as? CFRange {
      // Ensure range values are sensible before returning
      if range.location >= 0 && range.length >= 0 {
        print(
          "[AccessibilityTextService] Successfully retrieved selected text range: \(range.location)-\(range.location + range.length)"
        )
        return (Int(range.location), Int(range.length))
      } else {
        print("[AccessibilityTextService] Retrieved invalid selected text range: \(range)")
      }
    } else {
      print(
        "[AccessibilityTextService] Failed to retrieve AXSelectedTextRangeAttribute (Error: \(result.rawValue)), attempting alternative methods..."
      )
    }

    // Alternative method 1: Try to get the selection range as a value instead of a CFRange
    if let selectedRangeStr = getAttributeText(
      from: focusedUIElement,
      attribute: kAXSelectedTextRangeAttribute as CFString
    ) {
      print("[AccessibilityTextService] Got selection range as string: \(selectedRangeStr)")
      // Parse the range string if in a known format
      // Format might be like "{123, 45}" depending on the app
      let cleaned = selectedRangeStr.trimmingCharacters(in: CharacterSet(charactersIn: "{}"))
      let components = cleaned.components(separatedBy: ",")
      if components.count == 2,
        let startStr = components.first?.trimmingCharacters(in: .whitespacesAndNewlines),
        let lengthStr = components.last?.trimmingCharacters(in: .whitespacesAndNewlines),
        let start = Int(startStr), let length = Int(lengthStr),
        start >= 0, length >= 0  // Add validation
      {
        print("[AccessibilityTextService] Parsed range from string: start=\(start), length=\(length)")
        return (start, length)
      } else {
        print("[AccessibilityTextService] Failed to parse range from string: \(selectedRangeStr)")
      }
    }

    // Alternative method 2: Infer range from full text and selected text
    if let fullText = fullText,
      let selectedText = getAttributeText(
        from: focusedUIElement,
        attribute: kAXSelectedTextAttribute as CFString
      ),
      !selectedText.isEmpty
    {

      // If we have the visible range attribute, use it to constrain our search
      var visibleRange: (start: Int, length: Int)?
      var visibleRangeValue: AnyObject?
      if AXUIElementCopyAttributeValue(
        focusedUIElement,
        kAXVisibleCharacterRangeAttribute as CFString,
        &visibleRangeValue
      ) == .success,
        let vRange = visibleRangeValue as? CFRange,
        vRange.location >= 0, vRange.length >= 0  // Add validation
      {
        visibleRange = (Int(vRange.location), Int(vRange.length))
        print("[AccessibilityTextService] Using visible range for search: \(visibleRange!)")
      }

      // Check if we can find the selection in the visible range first, then the full document
      if let range = findSelectionRange(in: fullText, selectedText: selectedText, visibleRange: visibleRange)
      {
        print(
          "[AccessibilityTextService] Computed selection range from text: \(range.start)-\(range.start + range.length)"
        )
        return range
      } else {
        print(
          "[AccessibilityTextService] Could not find selection '\(selectedText.prefix(50))...' within full text using findSelectionRange."
        )
      }
    } else if fullText == nil {
      print("[AccessibilityTextService] Cannot infer range: full text is nil.")
    } else if getAttributeText(from: focusedUIElement, attribute: kAXSelectedTextAttribute as CFString) == nil
    {
      print("[AccessibilityTextService] Cannot infer range: selected text is nil.")
    }

    print("[AccessibilityTextService] Unable to determine selected text range through any method.")
    return nil
  }

  /// Helper function to find the selection range in text
  private func findSelectionRange(
    in fullText: String,
    selectedText: String,
    visibleRange: (start: Int, length: Int)?
  ) -> (start: Int, length: Int)? {
    // If we know the visible range, try to find the selection within that range first
    if let visibleRange = visibleRange {
      let visibleStartIndex = fullText.index(
        fullText.startIndex,
        offsetBy: min(visibleRange.start, fullText.count - 1)
      )
      let visibleEndIndex = fullText.index(
        visibleStartIndex,
        offsetBy: min(
          visibleRange.length,
          fullText.count - fullText.distance(from: fullText.startIndex, to: visibleStartIndex) - 1
        )
      )
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
        of: "\\s+",
        with: " ",
        options: .regularExpression
      )
      let simplifiedSelection = selectedText.replacingOccurrences(
        of: "\\s+",
        with: " ",
        options: .regularExpression
      )

      if let range = simplifiedFullText.range(of: simplifiedSelection) {
        // This is approximate, but better than nothing
        let approxStart = simplifiedFullText.distance(
          from: simplifiedFullText.startIndex,
          to: range.lowerBound
        )
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
      let url = URL(fileURLWithPath: documentPath)
      // Ensure filename is not empty
      if !url.lastPathComponent.isEmpty {
        print(
          "[AccessibilityTextService] Found document path: \(documentPath), file: \(url.lastPathComponent)"
        )
        return url.lastPathComponent
      }
    }

    print("[AccessibilityTextService] No document path found or filename empty. Trying main window title...")

    // Use helper to get title and extract filename
    if let windowTitle = getMainWindowTitle(from: appElement),
      let fileName = extractFileNameFromTitle(windowTitle)
    {
      print("[AccessibilityTextService] Extracted file name from title: \(fileName)")
      return fileName
    }

    print("[AccessibilityTextService] No valid file name found.")
    return nil
  }

  // MARK: - Helper Functions for Window/File Info

  /// Helper to get the main window title from an application element.
  private func getMainWindowTitle(from appElement: AXUIElement) -> String? {
    var windowElement: AnyObject?
    guard
      AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowElement) == .success,
      let windowArray = windowElement as? [AXUIElement],
      let mainWindow = windowArray.first
    else {
      print("[AccessibilityTextService] Could not get main window element.")
      return nil
    }

    if let windowTitle = getAttributeText(from: mainWindow, attribute: kAXTitleAttribute as CFString) {
      print("[AccessibilityTextService] Found window title: \(windowTitle)")
      return windowTitle
    } else {
      print("[AccessibilityTextService] Could not get window title attribute.")
      return nil
    }
  }

  /// Helper to extract a likely filename from a window title using regex.
  private func extractFileNameFromTitle(_ windowTitle: String) -> String? {
    do {
      // Regex to find a valid filename with an extension
      // Made slightly more robust: allows dots in filename before the extension
      let regex = try NSRegularExpression(pattern: #"\b[\w\s.,-]+?\.[A-Za-z0-9]+(?=\b|\s|$)"#, options: [])
      let range = NSRange(location: 0, length: windowTitle.utf16.count)

      // Find the *last* match, as titles might include paths (e.g., "file.txt - /path/to/file.txt - Editor")
      let matches = regex.matches(in: windowTitle, options: [], range: range)
      if let match = matches.last {
        let matchedString = (windowTitle as NSString).substring(with: match.range)
        // Basic sanitization: trim whitespace
        let potentialFileName = matchedString.trimmingCharacters(in: .whitespacesAndNewlines)
        // Optional: Add more validation if needed (e.g., check for invalid characters)
        if !potentialFileName.isEmpty {
          return potentialFileName
        }
      }
    } catch {
      print("[AccessibilityTextService] Failed to create regex for filename extraction: \(error)")
    }
    return nil
  }
}
