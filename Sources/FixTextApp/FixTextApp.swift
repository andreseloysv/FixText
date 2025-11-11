import SwiftUI
import AppKit

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

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        HotKeyManager.shared.register(handler: { [weak self] in
            self?.toggleWindow()
        })
    }

    func applicationWillTerminate(_ notification: Notification) {
        HotKeyManager.shared.unregister()
    }

    func register(window: NSWindow) {
        guard self.window !== window else { return }
        self.window = window
        configure(window: window)
        viewModel?.prefillPromptFromClipboard()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        viewModel?.forceFocus()
    }

    func toggleWindow() {
        guard let window = window else { return }

        if window.isVisible {
            window.orderOut(nil)
        } else {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
            viewModel?.prefillPromptFromClipboard(autoSubmit: true)
            viewModel?.forceFocus()
        }
    }

    private func configure(window: NSWindow) {
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
}
