# CopyPaster

A native macOS clipboard manager with a Liquid Glass interface. CopyPaster lives in the menu bar, remembers everything you copy — text, images and file paths — and keeps it searchable across restarts.

<p align="center">
  <img src="docs/screenshots/main.png" alt="CopyPaster window showing text, link, image and file path items" width="520">
</p>

## Features

- **Full clipboard history** — text, images and copied files/folders, newest first, saved between launches (up to 500 items; pinned items are never trimmed).
- **Menu bar popover** — open it from the menu bar icon or with **⌘⇧V** from anywhere.
- **Search and filters** — instant search plus All / Text / Images / pwd tabs with live counts.
- **Pin favorites** — pinned items stay at the top and are never trimmed by the history limit.
- **Open links** — items containing URLs get a button (or a menu, for several links) to open them in your browser.
- **Weblinks log** — every link you copy is also recorded in `~/Documents/Weblinks.html`, newest first, with clickable links.
- **Open in Terminal** — copied files, folders or paths (e.g. `pwd` output) get a button that opens Terminal in that folder.
- **Drag images out** — drag an image tile straight into Finder, Mail, Slack or any other app.
- **Screenshots to disk** — images that only exist on the clipboard (like ⌘⌃⇧4 screenshots) are saved to a folder so you can reveal or copy their path.
- **Snippets** — type text into the compose panel to add it to your history without copying it first.
- **Password masking** — passwords are shown as `A••••••••` with a lock badge. Copies tagged as secret by password managers (LastPass, 1Password, Bitwarden) are labelled **Password**; text that looks like a password or API key is labelled **Might be password**. Hold the eye button to reveal, right-click to mark or unmark. Masked items don't match searches on their hidden text, and aren't added to the Weblinks log when they come from a password manager.
- **Pause monitoring** — stop recording temporarily while you copy something sensitive.
- **Launch at Login** — toggle it in Settings (⌘,).
- **Encrypted history** — saved history is encrypted with AES-256-GCM, so copied passwords never sit on disk in plain text. The key lives in your login Keychain. History saved by older versions is encrypted automatically on first launch.
- **Private by design** — no network access, no analytics; everything stays on your Mac.

## Requirements

- macOS 15 Sequoia or later (Liquid Glass on macOS 26+, frosted materials on 15)
- Full Xcode 26 or later to build (the Command Line Tools alone are not enough)
- No Apple Developer account needed — the build is ad-hoc signed for your own Mac

## Build and install

```bash
git clone https://github.com/vishal781992/copyPaster.git
cd copyPaster
xcodebuild -project copyPaster.xcodeproj -scheme copyPaster -configuration Release \
  -derivedDataPath build CODE_SIGN_IDENTITY="-" CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM="" build
pkill -x copyPaster 2>/dev/null; rm -rf /Applications/copyPaster.app
cp -R build/Build/Products/Release/copyPaster.app /Applications/
open /Applications/copyPaster.app
```

Or open `copyPaster.xcodeproj` in Xcode and press **⌘R**.

The global **⌘⇧V** shortcut listens for key presses in other apps, so macOS will ask you to allow CopyPaster under **System Settings → Privacy & Security → Accessibility**.

## For AI agents

If a user hands you this repository (or its URL) and asks you to install CopyPaster on their Mac, follow these steps in order. Every command is non-interactive except where marked **user action**.

### 1. Check the machine

```bash
sw_vers -productVersion        # must be 15.0 or higher
xcode-select -p                # must point inside Xcode.app, not /Library/Developer/CommandLineTools
xcodebuild -version            # must be Xcode 26 or higher
```

- macOS below 15: stop and tell the user CopyPaster needs macOS 15 Sequoia or later.
- `xcode-select -p` prints `/Library/Developer/CommandLineTools`, but Xcode is installed in `/Applications`: run `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer` (needs the user's password — **user action**).
- Xcode missing or older than 26: ask the user to install the latest Xcode from the Mac App Store (**user action**), open it once to accept the license and finish component installs, then continue. `sudo xcodebuild -license accept` also accepts the license.

### 2. Get the source

```bash
git clone https://github.com/vishal781992/copyPaster.git
cd copyPaster
```

Skip the clone if you were given the folder already; just `cd` into it (the folder that contains `copyPaster.xcodeproj`).

### 3. Build

```bash
xcodebuild -project copyPaster.xcodeproj -scheme copyPaster -configuration Release \
  -derivedDataPath build CODE_SIGN_IDENTITY="-" CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM="" build
```

- Success ends with `** BUILD SUCCEEDED **`. The app is at `build/Build/Products/Release/copyPaster.app`.
- The signing overrides build an ad-hoc signed app, so no Apple ID, team or certificate is needed. Do not drop them: the project uses automatic signing and fails with "requires a development team" without them.
- There are no third-party dependencies — no Swift packages, CocoaPods or Homebrew installs to run.
- Compiler warnings are expected and harmless; only `error:` lines matter.

### 4. Install and launch

```bash
pkill -x copyPaster 2>/dev/null          # quit a running copy, if any
rm -rf /Applications/copyPaster.app      # remove an older install
cp -R build/Build/Products/Release/copyPaster.app /Applications/
open /Applications/copyPaster.app
```

If the user cannot write to `/Applications`, install to `~/Applications` instead (create it with `mkdir -p ~/Applications`).

### 5. Verify

```bash
pgrep -x copyPaster && echo "running"
codesign -dv /Applications/copyPaster.app 2>&1 | grep Identifier   # Identifier=vish.copyPaster
```

On launch CopyPaster opens its main window and adds a clipboard icon (`doc.on.clipboard`) to the menu bar that opens the same view as a popover.

### 6. Hand off to the user

Tell the user to finish these steps themselves — an agent cannot click through macOS privacy prompts:

1. **Accessibility permission** (**user action**): open **System Settings → Privacy & Security → Accessibility** and turn on **copyPaster**. This enables the global **⌘⇧V** shortcut. Clicking the menu bar icon works without it.
   Open the pane directly with `open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"`.
2. **Launch at Login** (optional): open CopyPaster, press **⌘,** and turn on **Launch at Login**.

### Updating an existing install

```bash
cd copyPaster && git pull
```

Then repeat steps 3–5. Ad-hoc signed builds get a new signature each time, which has two effects the user must handle (**user action**):

- macOS may drop the Accessibility permission. If ⌘⇧V stops working, remove copyPaster from the Accessibility list with the **−** button and add it again.
- On first launch after the update, macOS asks whether copyPaster may use the "CopyPaster history key" in the login Keychain. Click **Always Allow** (it may ask for the login password). **Deny** keeps the history file untouched but nothing is saved that session.

### Uninstall

```bash
pkill -x copyPaster 2>/dev/null
rm -rf /Applications/copyPaster.app
rm -rf ~/Library/Application\ Support/copyPaster        # clipboard history
defaults delete vish.copyPaster 2>/dev/null              # settings
security delete-generic-password -s vish.copyPaster      # history encryption key
```

`~/Documents/Weblinks.html` and saved images in `~/Pictures/Screenshots` belong to the user — leave them unless they ask you to delete them.

### Troubleshooting

| Symptom | Fix |
|---|---|
| `xcodebuild: error: tool 'xcodebuild' requires Xcode` | Only Command Line Tools are active. Install Xcode and run `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`. |
| `'glassEffect' is unavailable` or other SDK errors | Xcode is older than 26. Update Xcode. |
| `requires a development team` | The signing overrides in step 3 were left out. Re-run the exact build command. |
| `You have not agreed to the Xcode license agreements` | Run `sudo xcodebuild -license accept` (**user action**). |
| Menu bar icon missing | On a crowded menu bar it can be hidden behind the notch. Use the main window or press ⌘⇧V once Accessibility is granted. |
| Keychain prompt on every launch | The user clicked **Allow** instead of **Always Allow**. Ask them to click **Always Allow** next time. |
| Toast "Keychain locked — history not saved" | Keychain access was denied or the login keychain is locked. Relaunch and allow access. The history file is kept as is. |
| History empty after launch, `clipboard_history.enc.corrupt-…` file present | The file couldn't be decrypted (key deleted or file damaged), so it was moved aside and a new history started. Without the old key it can't be recovered. |
| "copyPaster can't be opened" | Only happens if the app was copied from another Mac or downloaded. Build it locally as above, or run `xattr -dr com.apple.quarantine /Applications/copyPaster.app`. |

## Configuration

| What | Where |
|---|---|
| Clipboard history (encrypted, owner-only `0600`) | `~/Library/Application Support/copyPaster/clipboard_history.enc` |
| History encryption key | login Keychain, item "CopyPaster history key" (service `vish.copyPaster`) |
| Saved clipboard images (not encrypted) | `~/Pictures/Screenshots` by default |
| Weblinks log (not encrypted) | `~/Documents/Weblinks.html` |

Only the history is encrypted. Saved images and the Weblinks log are files meant for you to open, so they stay readable. Older versions stored the history as plain `clipboard_history.json`; it is encrypted and deleted on first launch. macOS doesn't wipe the old disk blocks, so the plain copy is fully gone only once FileVault is on or the space is reused.

To save clipboard images somewhere else:

```bash
defaults write ~/Library/Preferences/vish.copyPaster imageSaveDirectory "/path/to/folder"
```

## Demo mode

Launch with `-demo YES` to show sample items instead of your real history. Nothing is read from or written to your history, and the clipboard isn't monitored — handy for screenshots.

```bash
open -n /Applications/copyPaster.app --args -demo YES
```

## Project layout

| File | Role |
|---|---|
| `ClipboardManager.swift` | Clipboard polling, capture, de-duplication, persistence, weblinks, Terminal |
| `ClipboardItem.swift` | Item model (text / image / file path) and link and folder detection |
| `ContentView.swift` | Header, search, filter bar, tile list, compose button |
| `ClipboardTileView.swift` | A single history tile and its actions |
| `PasswordDetector.swift` | Guesses whether copied text is a password or token |
| `SecureStore.swift` | AES-GCM encryption, Keychain key and encrypted history file |
| `GlassIcon.swift` | Shared Liquid Glass button and panel styles, with macOS 15 fallbacks |
| `AddTextView.swift` | Compose panel for snippets |
| `AppDelegate.swift` | Menu bar item, popover, ⌘⇧V hotkey |
| `DemoData.swift` | Sample items for demo mode |

Pure SwiftUI + AppKit — no third-party dependencies.

## License

MIT — see [LICENSE](LICENSE).
