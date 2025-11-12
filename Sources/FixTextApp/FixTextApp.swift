import SwiftUI
import AppKit
import Carbon.HIToolbox

@main
struct FixTextApp: App {
    @StateObject private var viewModel = AppViewModel()
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
                .environmentObject(viewModel)
                .background(WindowAccessor { window in
                    guard let window else { return }
                    appDelegate.viewModel = viewModel
                    appDelegate.register(window: window)
                })
        }
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Toggle FixText Window") {
                    appDelegate.toggleWindow()
                }
                .keyboardShortcut(.space, modifiers: [.command, .option])
            }
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private(set) weak var window: NSWindow?
    weak var viewModel: AppViewModel?
    private let selectionCapture = SelectionCaptureService()
    private var pendingSelectionSession: SelectionSession?
    private var confirmKeyTap: CFMachPort?
    private var confirmKeyRunLoopSource: CFRunLoopSource?
    private var confirmKeyTapRefcon: UnsafeMutableRawPointer?
    private let confirmKeyCodes: Set<CGKeyCode> = [
        CGKeyCode(kVK_Return),
        CGKeyCode(kVK_ANSI_KeypadEnter)
    ]

    private func logState(function: String = #function) {
        // LogManager.shared.log("---")
        // LogManager.shared.log("AppDelegate state in \(function):")
        // LogManager.shared.log("  - window: \(window.debugDescription)")
        // LogManager.shared.log("  - viewModel: \(viewModel.debugDescription)")
        // LogManager.shared.log("  - pendingSelectionSession: \(pendingSelectionSession.debugDescription)")
        // LogManager.shared.log("  - confirmKeyTap: \(confirmKeyTap.debugDescription)")
        // LogManager.shared.log("  - confirmKeyRunLoopSource: \(confirmKeyRunLoopSource.debugDescription)")
        // LogManager.shared.log("  - confirmKeyTapRefcon: \(confirmKeyTapRefcon.debugDescription)")
        // viewModel?.logState()
        // LogManager.shared.log("---")
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // LogManager.shared.deleteLogFile()
        logState()
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        HotKeyManager.shared.register(handler: { [weak self] in
            self?.toggleWindow()
        })
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        logState()
        clearSelectionSession()
    }

    func applicationWillTerminate(_ notification: Notification) {
        logState()
        HotKeyManager.shared.unregister()
        selectionCapture.clearPasteboard()
    }

    func register(window: NSWindow) {
        logState()
        guard self.window !== window else { return }
        self.window = window
        configure(window: window)
        viewModel?.selectionConfirmAction = { [weak self] in
            self?.confirmPendingSelectionResponse()
        }
        viewModel?.prefillPromptFromClipboard()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        viewModel?.forceFocus()
    }

    func toggleWindow() {
        logState()
        guard let window = window else { return }

        if window.isVisible {
            window.orderOut(nil)
            clearSelectionSession()
            return
        }

        let shouldActivateApp = NSApp.isActive

        Task { [weak self] in
            guard let self, let window = self.window else { return }
            await self.presentWindowWithSelection(window: window, activateApp: shouldActivateApp)
        }
    }

    private func presentWindowWithSelection(window: NSWindow, activateApp: Bool) async {
        logState()
        let sourceApp = NSWorkspace.shared.frontmostApplication
        let captureResult = activateApp ? nil : await selectionCapture.captureSelectedText()

        if activateApp {
            clearSelectionSession()
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
        } else {
            window.orderFrontRegardless()
        }

        if let captureResult {
            startSelectionSession(with: captureResult, sourceApp: sourceApp)
            viewModel?.prefillPrompt(with: captureResult.text, autoSubmit: true)
        } else if !activateApp {
            clearSelectionSession()
            viewModel?.prefillPromptFromClipboard(autoSubmit: true)
        }

        if activateApp {
            viewModel?.forceFocus()
        }
    }

    private func configure(window: NSWindow) {
        logState()
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isOpaque = false
        window.alphaValue = 0.93
        window.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.75)
        window.isMovableByWindowBackground = true
        window.level = .floating
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
    }

    private func startSelectionSession(
        with captureResult: SelectionCaptureService.CaptureResult,
        sourceApp: NSRunningApplication?
    ) {
        logState()
        let session = SelectionSession(captureResult: captureResult, sourceApp: sourceApp)
        pendingSelectionSession = session
        viewModel?.selectionResponseReady = false
        viewModel?.responseHandlerToken = session.id
        viewModel?.responseHandler = { [weak self] text in
            self?.handleSelectionResponse(text: text, sessionID: session.id) ?? false
        }
    }

    private func handleSelectionResponse(text: String, sessionID: UUID) -> Bool {
        logState()
        guard let session = pendingSelectionSession, session.id == sessionID else {
            return false
        }

        session.pendingResponse = text
        viewModel?.responseHandler = nil
        viewModel?.responseHandlerToken = nil

        if text.isEmpty {
            pendingSelectionSession = nil
            viewModel?.selectionResponseReady = false
            viewModel?.responseStatusMessage = "Empty response – nothing to insert."
            return true
        }

        viewModel?.selectionResponseReady = true
        viewModel?.responseStatusMessage = "Press Enter to apply to the selection."
        startConfirmKeyCapture()
        return true
    }

    private func confirmPendingSelectionResponse() {
        logState()
        guard let session = pendingSelectionSession else { return }
        stopConfirmKeyCapture()

        guard
            let response = session.pendingResponse,
            !response.isEmpty
        else {
            viewModel?.responseStatusMessage = "Waiting for Gemini response…"
            return
        }

        pendingSelectionSession = nil
        viewModel?.selectionResponseReady = false
        window?.orderOut(nil)

        Task { [weak self] in
            await self?.applySelectionReplacement(text: response, session: session)
        }
    }

    private func applySelectionReplacement(text: String, session: SelectionSession) async {
        logState()
        guard !text.isEmpty else {
            viewModel?.responseStatusMessage = "Empty response – nothing to insert."
            session.captureResult.restoreClipboard()
            return
        }

        if let sourceApp = session.sourceApp {
            let frontmostPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
            if frontmostPID != sourceApp.processIdentifier {
                let activated = sourceApp.activate(options: [])
                if !activated {
                    viewModel?.responseStatusMessage = "Couldn’t focus the original app."
                    session.captureResult.restoreClipboard()
                    return
                }
                try? await Task.sleep(nanoseconds: 80_000_000)
            }
        }

        let replaced = await selectionCapture.replaceSelection(with: text)
        session.captureResult.restoreClipboard()

        viewModel?.responseStatusMessage = replaced
            ? "Selection updated."
            : "Couldn’t update the selection."
    }

    private func clearSelectionSession() {
        logState()
        pendingSelectionSession = nil
        viewModel?.responseHandler = nil
        viewModel?.responseHandlerToken = nil
        viewModel?.selectionResponseReady = false
        viewModel?.reset()
        stopConfirmKeyCapture()
    }

    private final class SelectionSession {
        let id = UUID()
        let captureResult: SelectionCaptureService.CaptureResult
        let sourceApp: NSRunningApplication?
        var pendingResponse: String?

        init(
            captureResult: SelectionCaptureService.CaptureResult,
            sourceApp: NSRunningApplication?
        ) {
            self.captureResult = captureResult
            self.sourceApp = sourceApp
        }
    }

    private func startConfirmKeyCapture() {
        logState()
        guard confirmKeyTap == nil else { return }

        let eventMask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        let refcon = UnsafeMutableRawPointer(Unmanaged.passRetained(self).toOpaque())
        confirmKeyTapRefcon = refcon

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { _, type, event, refcon in
                guard let refcon else {
                    return Unmanaged.passUnretained(event)
                }

                let delegate = Unmanaged<AppDelegate>
                    .fromOpaque(refcon)
                    .takeUnretainedValue()

                return delegate.handleConfirmKeyEvent(type: type, event: event)
            },
            userInfo: refcon
        ) else {
            stopConfirmKeyCapture()
            return
        }

        confirmKeyTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        confirmKeyRunLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func stopConfirmKeyCapture() {
        logState()
        if let tap = confirmKeyTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }

        if let source = confirmKeyRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .defaultMode)
        }

        if let refcon = confirmKeyTapRefcon {
            Unmanaged<AppDelegate>.fromOpaque(refcon).release()
            confirmKeyTapRefcon = nil
        }

        confirmKeyRunLoopSource = nil
        confirmKeyTap = nil
    }

    private func handleConfirmKeyEvent(
        type: CGEventType,
        event: CGEvent
    ) -> Unmanaged<CGEvent>? {
        logState()
        guard type == .keyDown else {
            return Unmanaged.passRetained(event)
        }

        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        guard
            confirmKeyCodes.contains(keyCode),
            viewModel?.selectionResponseReady == true
        else {
            return Unmanaged.passRetained(event)
        }

        stopConfirmKeyCapture()
        DispatchQueue.main.async { [weak self] in
            Task { [weak self] in
                self?.confirmPendingSelectionResponse()
            }
        }

        return nil
    }
}
