import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: AppViewModel
    @FocusState private var promptIsFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            GroupBox("Gemini API Key") {
                VStack(alignment: .leading, spacing: 8) {
                    SecureField("Enter your API key", text: $viewModel.apiKeyInput)
                        .textFieldStyle(.roundedBorder)

                    HStack(spacing: 10) {
                        Button("Save Key") {
                            viewModel.saveAPIKey()
                        }
                        .disabled(viewModel.apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                        Button("Delete Key") {
                            viewModel.deleteAPIKey()
                        }
                        .disabled(!viewModel.hasStoredKey)

                        if viewModel.hasStoredKey {
                            Label("Key saved", systemImage: "checkmark.shield.fill")
                                .foregroundStyle(.green)
                                .font(.footnote)
                        }

                        Spacer()
                    }

                    if let status = viewModel.keyStatusMessage {
                        Text(status)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Text("Prompt")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextEditor(text: $viewModel.prompt)
                .font(.body.monospaced())
                .focused($promptIsFocused)
                .frame(minHeight: 160)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.08))
                )

            HStack(spacing: 12) {
                Button {
                    viewModel.submitPrompt()
                } label: {
                    if viewModel.isLoading {
                        ProgressView()
                            .controlSize(.small)
                            .progressViewStyle(.circular)
                    } else {
                        Text("Send to Gemini")
                    }
                }
                .keyboardShortcut(.return, modifiers: [.command])
                .disabled(viewModel.isLoading)

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                } else if !viewModel.response.isEmpty {
                    Text("Response copied to clipboard")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            Divider()

            Text("Response")
                .font(.caption)
                .foregroundStyle(.secondary)

            ScrollView {
                Text(responseText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .font(.body.monospaced())
                    .padding(8)
            }
            .frame(maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.05))
            )
        }
        .padding(20)
        .frame(minWidth: 460, minHeight: 520)
        .background(.clear)
        .onAppear {
            promptIsFocused = true
        }
        .onChange(of: viewModel.focusToken) { _ in
            promptIsFocused = true
        }
    }

    private var responseText: String {
        viewModel.response.isEmpty ? "Response will appear here." : viewModel.response
    }
}
