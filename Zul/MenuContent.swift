import SwiftUI

struct MenuContent: View {
  let nowPlaying: NowPlayingService
  let lyrics: LyricsController
  @Binding var isMovingOverlay: Bool
  @AppStorage(Preferences.overlayVisible.key) private var isOverlayVisible = Preferences.overlayVisible.defaultValue
  @Environment(\.openSettings) private var openSettings

  var body: some View {
    if let track = nowPlaying.nowPlaying {
      Text(track.artist.isEmpty ? track.title : "\(track.title) — \(track.artist)")
      if let status {
        Text(status)
      }
    } else {
      Text("Nothing Playing")
    }
    Divider()

    Toggle("Show Lyrics", isOn: $isOverlayVisible)
    Toggle("Move Overlay", isOn: $isMovingOverlay)
    Menu(
      "Track Offset: \(lyrics.trackOffset.formatted(.number.precision(.fractionLength(2)).sign(strategy: .always()))) s"
    ) {
      Button("Show Lyrics Sooner (+0.25 s)") { lyrics.setTrackOffset(lyrics.trackOffset + 0.25) }
      Button("Show Lyrics Later (−0.25 s)") { lyrics.setTrackOffset(lyrics.trackOffset - 0.25) }
      Button("Reset") { lyrics.setTrackOffset(0) }
        .disabled(lyrics.trackOffset == 0)
    }
    .disabled(!hasSyncedLyrics)
    Divider()

    Button("Settings…") {
      // A menu bar app is never active, so the window would open behind the frontmost app.
      NSApplication.shared.activate(ignoringOtherApps: true)
      openSettings()
    }
    .keyboardShortcut(",")
    Button("Quit") {
      NSApplication.shared.terminate(nil)
    }
    .keyboardShortcut("q")
  }

  private var hasSyncedLyrics: Bool {
    if case .synced = lyrics.lyrics { return true }
    return false
  }

  // Only shown when it explains why the overlay stays empty. Nil while searching or after
  // a network error; those don't say anything about the track.
  private var status: String? {
    lyrics.lyrics == .notFound ? "No synced lyrics found" : nil
  }
}
