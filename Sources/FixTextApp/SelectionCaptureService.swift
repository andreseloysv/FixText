import AppKit
import Carbon.HIToolbox
import Quartz

@MainActor
final class SelectionCaptureService {
    struct CaptureResult {
        let text: String
        let restoreClipboard: () -> Void
    }

    func captureSelectedText(timeout: TimeInterval = 0.6) async -> CaptureResult? {
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
        keyDown.flags = [.maskCommand]
        keyUp.flags = [.maskCommand]
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }

    private func snapshotPasteboardItems(_ items: [NSPasteboardItem]?) -> [NSPasteboardItem] {
        guard let items, !items.isEmpty else { return [] }

        return items.map { item in
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) {
                    copy.setData(data, forType: type)
                }
            }
            return copy
        }
    }

    private func restorePasteboard(_ pasteboard: NSPasteboard, with items: [NSPasteboardItem]) {
        pasteboard.clearContents()
        guard !items.isEmpty else { return }
        pasteboard.writeObjects(items as [NSPasteboardWriting])
    }
}
