# FixText

Small macOS helper that lets you jot down a prompt, send it to the Gemini API, and instantly copy the response to your clipboard. The app keeps a semi–transparent window ready to go and can be toggled at any time with a global shortcut.

## Requirements

- macOS 13 or later
- Swift 6 toolchain (Xcode 15.3+ or the standalone Command Line Tools)
- A Gemini API key (<https://aistudio.google.com/app/apikey>)

## Running the app

```bash
cd /path/to/fixtext
swift run FixText
```

`swift run` builds the SwiftUI executable and launches the translucent window. Keep the process running to continue using the global shortcut.

### Add your Gemini key in-app

1. Open the **Gemini API Key** box at the top of the window.
2. Paste your key into the secure field and press **Save Key**.
3. The key is stored in the macOS Keychain, so you only have to do this once.
4. Use **Delete Key** anytime you want to remove the stored credential.

## Keyboard shortcut

- `⌘⌥U` toggles the window (registers at launch). You can change the key combination inside `HotKeyManager.register`.
- When summoned, the window floats above everything else so you can jot text without hunting for focus.
- As soon as the shortcut brings the window forward, the current clipboard text auto-fills the editor and immediately sends to Gemini so you get a corrected result without clicking anything.

Whenever the window becomes visible it gains focus automatically and the text editor is ready for input.

## Workflow

1. Type your prompt in the editor (or just copy text and hit `⌘⌥U` to auto-populate and send).
2. Hit **Send to Gemini** (or `⌘↩`) to call the API.
3. The app sends your text as `Fix the following text:` so Gemini returns only the corrected content—no explanations.
4. The response (from `gemini-2.5-flash-lite`) appears in the lower panel, is copied to the clipboard, and the window stays semi-transparent so you can keep context.

Errors (such as missing API keys or HTTP failures) are displayed inline above the response area.
