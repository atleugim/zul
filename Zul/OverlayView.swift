import SwiftUI

struct OverlayView: View {
  let nowPlaying: NowPlayingService
  let lyrics: LyricsController
  @AppStorage(Preferences.overlayVisible.key) private var isEnabled = Preferences.overlayVisible.defaultValue
  @AppStorage(Preferences.overlayOpacity.key) private var opacity = Preferences.overlayOpacity.defaultValue

  private var lines: [LyricLine]? {
    guard isEnabled, nowPlaying.nowPlaying?.isPlaying == true, case .synced(let lines) = lyrics.lyrics else {
      return nil
    }
    return lines
  }

  var body: some View {
    ZStack {
      if let track = nowPlaying.nowPlaying, let lines {
        SyncedLyricsView(nowPlaying: track, lines: lines, trackOffset: lyrics.trackOffset)
          .opacity(opacity)
          .transition(.opacity)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .animation(.timingCurve(0.23, 1, 0.32, 1, duration: 0.2), value: lines == nil)
    .onChange(of: nowPlaying.nowPlaying, initial: true) { _, track in
      lyrics.update(for: track)
    }
  }
}
