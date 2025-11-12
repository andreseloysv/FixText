import AppKit
import Carbon.HIToolbox
import Quartz

@MainActor
final class SelectionCaptureService {
    struct CaptureResult {
        let text: String
        let restoreClipboard: () -> Void
    }

    /// Check if the app has accessibility permissions
    nonisolated static func checkAccessibilityPermissions() -> Bool {
        // Use string literal to avoid Swift 6 concurrency warnings with kAXTrustedCheckOptionPrompt
        let options: NSDictionary = ["AXTrustedCheckOptionPrompt": true]
        let accessEnabled = AXIsProcessTrustedWithOptions(options)
        return accessEnabled
    }

    private func logState(function: String = #function) {
        // LogManager.shared.log("---")
        // LogManager.shared.log("SelectionCaptureService state in \(function):")
        // LogManager.shared.log("---")
    }

    func captureSelectedText(timeout: TimeInterval = 0.6) async -> CaptureResult? {
        logState()

        // Verify accessibility permissions without prompting
        let options: NSDictionary = ["AXTrustedCheckOptionPrompt": false]
        let hasPermissions = AXIsProcessTrustedWithOptions(options)
        guard hasPermissions else {
            print("FixText: Missing Accessibility permissions - cannot capture text")
            return nil
        }

        let pasteboard = NSPasteboard.general
        let snapshot = snapshotPasteboardItems(pasteboard.pasteboardItems)
        let initialChangeCount = pasteboard.changeCount

        guard sendCopyShortcut() else {
            restorePasteboard(pasteboard, with: snapshot)
            return nil
        }

        let didUpdate = await waitForPasteboardChange(
            pasteboard: pasteboard,
            initialChangeCount: initialChangeCount,
            timeout: timeout
        )

        guard didUpdate,
              let copiedText = pasteboard.string(forType: .string),
              !copiedText.isEmpty else {
            restorePasteboard(pasteboard, with: snapshot)
            return nil
        }

        return CaptureResult(text: copiedText) { [snapshot] in
            let pasteboard = NSPasteboard.general
            self.restorePasteboard(pasteboard, with: snapshot)
        }
    }

    func replaceSelection(with text: String) async -> Bool {
        logState()
        guard !text.isEmpty else { return false }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        guard sendPasteShortcut() else {
            return false
        }

        try? await Task.sleep(nanoseconds: 150_000_000)
        return true
    }

    private func waitForPasteboardChange(
        pasteboard: NSPasteboard,
        initialChangeCount: Int,
        timeout: TimeInterval
    ) async -> Bool {
        logState()
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            if pasteboard.changeCount != initialChangeCount {
                return true
            }

            try? await Task.sleep(nanoseconds: 50_000_000)
        }

        return false
    }

    private func sendCopyShortcut() -> Bool {
        logState()
        guard
            let source = CGEventSource(stateID: .hidSystemState),
            let keyDown = CGEvent(
                keyboardEventSource: source,
                virtualKey: CGKeyCode(kVK_ANSI_C),
                keyDown: true
            ),
            let keyUp = CGEvent(
                keyboardEventSource: source,
                virtualKey: CGKeyCode(kVK_ANSI_C),
                keyDown: false
            )
        else {
            return false
        }

        send(keyDown: keyDown, keyUp: keyUp)

        return true
    }

    private func sendPasteShortcut() -> Bool {
        logState()
        guard
            let source = CGEventSource(stateID: .hidSystemState),
            let keyDown = CGEvent(
                keyboardEventSource: source,
                virtualKey: CGKeyCode(kVK_ANSI_V),
                keyDown: true
            ),
            let keyUp = CGEvent(
                keyboardEventSource: source,
                virtualKey: CGKeyCode(kVK_ANSI_V),
                keyDown: false
            )
        else {
            return false
        }

        send(keyDown: keyDown, keyUp: keyUp)

        return true
    }

    private func send(keyDown: CGEvent, keyUp: CGEvent) {
        logState()
        keyDown.flags = [.maskCommand]
        keyUp.flags = [.maskCommand]
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }

    private struct PasteboardSnapshot {
        struct Item {
            let types: [NSPasteboard.PasteboardType]
            let data: [NSPasteboard.PasteboardType: Data]
        }

        let items: [Item]
    }

    private func snapshotPasteboardItems(_ items: [NSPasteboardItem]?) -> PasteboardSnapshot {
        logState()
        guard let items, !items.isEmpty else { return PasteboardSnapshot(items: []) }

        let snapshotItems = items.map { item -> PasteboardSnapshot.Item in
            let types = item.types
            var data = [NSPasteboard.PasteboardType: Data]()
            for type in types {
                if let itemData = item.data(forType: type) {
                    data[type] = itemData
                }
            }
            return PasteboardSnapshot.Item(types: types, data: data)
        }

        return PasteboardSnapshot(items: snapshotItems)
    }

    func clearPasteboard() {
        logState()
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
    }

    private func restorePasteboard(_ pasteboard: NSPasteboard, with snapshot: PasteboardSnapshot) {
        logState()
        pasteboard.clearContents()
        guard !snapshot.items.isEmpty else { return }

        let pasteboardItems = snapshot.items.map { snapshotItem -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for type in snapshotItem.types {
                if let data = snapshotItem.data[type] {
                    item.setData(data, forType: type)
                }
            }
            return item
        }

        pasteboard.writeObjects(pasteboardItems)
    }
}
