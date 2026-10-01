# Zul

A macOS menu bar app that shows synced lyrics for whatever is playing, in a floating overlay over your desktop.

Zul reads the system's Now Playing info, so it works with any player that reports to it (Apple Music, Spotify, browsers, etc.), and fetches time-synced lyrics from [LRCLIB](https://lrclib.net).

## Features

- Floating, click-through overlay that shows the current line in sync with playback.
- Works with any app that publishes to macOS Now Playing.
- Synced lyrics from LRCLIB, cached on disk so each song is only fetched once.
- Per-track offset (±0.25 s from the menu) and a global output latency offset for AirPlay or Bluetooth delay.
- Overlay position (top, bottom or dragged anywhere), opacity, and an option to show it on all desktops.
- Font family, size and color.
- Launch at login.

## Requirements

macOS 14 or later.

## Installation

Zul isn't notarized by Apple, so macOS blocks a downloaded copy the first time it opens.

### Homebrew

```sh
brew install --cask atleugim/tap/zul
```

The cask removes the quarantine flag after installing, which skips that Gatekeeper check.

### Manual

1. Download `Zul-<version>.dmg` from the [latest release](https://github.com/atleugim/zul/releases/latest).
2. Open it and drag **Zul** to **Applications**.
3. Open Zul from Applications.

To get past the block on first launch:

1. When macOS says it can't verify Zul, click **Done**.
2. Open **System Settings > Privacy & Security** and scroll down to **Security**.
3. Next to the message saying Zul was blocked, click **Open Anyway** and confirm with your password.

Or, from the Terminal, remove the quarantine flag macOS puts on downloaded apps:

```sh
xattr -dr com.apple.quarantine /Applications/Zul.app
```

You only need to do this once. Zul then opens normally, and it doesn't ask for any other permissions.

## Usage

Zul lives in the menu bar (music note icon) and has no Dock icon.

- **Show Lyrics**: toggles the overlay.
- **Move Overlay**: makes the overlay draggable; turn it off to make it click-through again.
- **Track Offset**: nudges the lyrics for the current song when they're early or late. Saved per track.
- **Settings…** (`⌘,`): launch at login, global latency offset, font, position, opacity and desktops.

If audio reaches you late (e.g. over AirPlay), set a negative **Output Latency Offset** in Settings, around −2 s for AirPlay.

## Development

### Prerequisites

- Xcode
- CMake (to build the bundled `mediaremote-adapter`)

### Building

```sh
git clone https://github.com/atleugim/zul.git
cd zul
```

Build the MediaRemote adapter framework, which the Xcode project embeds from `Vendor/build`:

```sh
scripts/build-adapter.sh
```

Then open `Zul.xcodeproj` and run the `Zul` scheme.

### Packaging a DMG

```sh
scripts/build-dmg.sh
```

Builds a universal Release `Zul.app` and writes `build/Zul-<version>.dmg`. It builds the adapter first if it's missing.

### Formatting

The code is formatted with `swift format` (bundled with Xcode), using the repo's `.swift-format`:

```sh
swift format -i -r Zul ZulTests
```

### Tests

Run the `ZulTests` target from Xcode (`⌘U`) or:

```sh
xcodebuild test -project Zul.xcodeproj -scheme Zul -destination "platform=macOS"
```

## License

MIT. See [LICENSE](LICENSE).

Bundles [mediaremote-adapter](https://github.com/ungive/mediaremote-adapter) under the BSD 3-Clause License. See [THIRD-PARTY-NOTICES](THIRD-PARTY-NOTICES).
