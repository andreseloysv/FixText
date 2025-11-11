# FixText

FixText is a tiny macOS helper that fixes grammar and wording using Google’s Gemini models. Copy any text, tap a global shortcut, and your corrected text appears on the clipboard moments later.

---

## For non-technical folks

### 1. Download everything
1. Go to <https://github.com/andreseloyasanchezva/fixtext>.
2. Click the green **Code** button, then **Download ZIP**.
3. Double-click the ZIP to get the `fixtext` folder.

### 2. Install FixText.app
1. Open the `fixtext` folder.
2. Drag the included `FixText.app` into Applications (or anywhere you prefer).  
   *(Only run `build_fixtext_app.sh` if you want to rebuild from source.)*

### 3. Add your Gemini API key
1. Double-click `FixText.app`.
2. Click **Gemini API Key**, paste your key, and hit **Save Key**.  
   The key stays in your macOS Keychain, so you only enter it once.

### 4. Daily workflow
1. Copy the text you want to fix.
2. Press `⌥⌘U` (Option + Command + U).  
   - The FixText window pops up on top.  
   - Your clipboard text auto-fills and is sent to Gemini instantly.  
3. Wait a second for the corrected text to appear (FixText copies it to your clipboard).
4. Press `⌥⌘U` again to hide the window.
5. Paste wherever you need—the clipboard already has the corrected text.

That’s it! From now on: copy → `⌥⌘U` → wait → `⌥⌘U` → paste.

---

## For technical users

### Requirements
- macOS 13+
- Swift 6 toolchain (`xcode-select --install` or Xcode 15.3+)
- Gemini API key (<https://aistudio.google.com/app/apikey>)

### Clone & run
```bash
git clone https://github.com/andreseloyasanchezva/fixtext
cd fixtext
swift run FixText
```

### Build the .app bundle
```bash
bash build_fixtext_app.sh   # optional: regenerates FixText.app from source
open FixText.app
```

### Behavior overview
- SwiftUI + AppKit hybrid window, semi-transparent, always floats.
- Global shortcut `⌥⌘U` registered via Carbon hotkey API.
- Clipboard text auto-fills the editor on each toggle and immediately submits to `gemini-2.5-flash-lite`.
- Prompt automatically gets prefixed with “Fix the following text…” to force explanation-free replies.
- Responses are copied to the clipboard, pasted board is cleared before writes.
- API key stored securely in Keychain; UI hides the input once a key exists.

Modify the shortcut or prompt logic in `Sources/FixTextApp/HotKeyManager.swift` and `AppViewModel.swift`. Rebuild with `swift run FixText` or `swift build -c release`.
