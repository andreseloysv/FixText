import SwiftUI
import AppKit

@MainActor
final class AppViewModel: ObservableObject {
    @Published var prompt: String = ""
    @Published var response: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published private(set) var focusToken = UUID()
    @Published var apiKeyInput: String = ""
    @Published private(set) var hasStoredKey: Bool = false
    @Published var keyStatusMessage: String?
    @Published var responseStatusMessage: String?
    @Published var selectionResponseReady: Bool = false

    private let service = GeminiService()
    private var storedKey: String?
    var responseHandler: ((String) -> Bool)?
    var responseHandlerToken: UUID?
    var selectionConfirmAction: (() -> Void)?

    init() {
        loadStoredKey()
    }

    func submitPrompt() {
        guard let key = storedKey, !key.isEmpty else {
            errorMessage = "Add your Gemini API key first."
            return
        }

        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let text = prompt
        let handlerToken = responseHandlerToken
        if handlerToken != nil {
            selectionResponseReady = false
        }
        Task {
            responseStatusMessage = nil
            let preparedPrompt = buildInstructionPrompt(for: text)
            await sendRequest(text: preparedPrompt, apiKey: key, handlerToken: handlerToken)
        }
    }

    func forceFocus() {
        focusToken = UUID()
    }

    func confirmSelectionReplacement() {
        guard selectionResponseReady else { return }
        selectionConfirmAction?()
    }

    func saveAPIKey() {
        let key = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            keyStatusMessage = "Enter a valid key before saving."
            return
        }

        do {
            try APIKeyStore.save(key)
            storedKey = key
            hasStoredKey = true
            apiKeyInput = ""
            keyStatusMessage = "API key saved securely."
        } catch {
            keyStatusMessage = error.localizedDescription
        }
    }

    func deleteAPIKey() {
        do {
            _ = try APIKeyStore.delete()
            storedKey = nil
            hasStoredKey = false
            keyStatusMessage = "API key deleted."
        } catch {
            keyStatusMessage = error.localizedDescription
        }
    }

    func loadStoredKey() {
        do {
            storedKey = try APIKeyStore.load()
            hasStoredKey = (storedKey?.isEmpty == false)
            keyStatusMessage = hasStoredKey ? "API key loaded." : "No API key saved."
        } catch {
            hasStoredKey = false
            keyStatusMessage = error.localizedDescription
        }
    }

    @discardableResult
    func prefillPromptFromClipboard(autoSubmit: Bool = false) -> Bool {
        let pasteboard = NSPasteboard.general
        guard let clipboardText = pasteboard.string(forType: .string), !clipboardText.isEmpty else {
            return false
        }

        return prefillPrompt(with: clipboardText, autoSubmit: autoSubmit)
    }

    @discardableResult
    func prefillPrompt(with text: String, autoSubmit: Bool = false) -> Bool {
        guard !text.isEmpty else { return false }
        prompt = text

        if autoSubmit {
            submitPrompt()
        }

        return true
    }

    private func buildInstructionPrompt(for userInput: String) -> String {
        """
        Fix the following text and output only the corrected version without any explanation or commentary. Preserve formatting when possible.
        ---
        \(userInput)
        """
    }

    private func sendRequest(text: String, apiKey: String, handlerToken: UUID?) async {
        isLoading = true
        errorMessage = nil
        responseStatusMessage = nil

        do {
            let reply = try await service.send(prompt: text, apiKey: apiKey)
            response = reply
            var handledExternally = false

            if let handler = responseHandler {
                if let handlerToken,
                   handlerToken == responseHandlerToken {
                    responseHandler = nil
                    responseHandlerToken = nil
                    handledExternally = handler(reply)
                }
            }

            if !handledExternally {
                copyToClipboard(reply)
                responseStatusMessage = "Response copied to clipboard."
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}
