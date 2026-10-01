import SwiftUI

struct SyncedLyricsView: View {
  let nowPlaying: NowPlaying
  let lines: [LyricLine]
  let trackOffset: TimeInterval
  // Compensates output latency (e.g. AirPlay); negative shows lyrics later.
  @AppStorage(Preferences.globalOffset.key) private var globalOffset = Preferences.globalOffset.defaultValue

  var body: some View {
    let offset = globalOffset + trackOffset
    // Redraws only when a line starts instead of polling the position. Play, pause, seek and
    // offset changes all rebuild this view, so the schedule is recomputed for each of them.
    // The small nudge keeps floating-point error from sampling a hair before the boundary.
    let lineStarts = lines.compactMap { nowPlaying.date(atPosition: $0.time - offset)?.addingTimeInterval(0.005) }
    TimelineView(.explicit(lineStarts)) { context in
      let position = nowPlaying.position(at: context.date) + offset
      LyricWindow(lines: lines, current: SyncEngine.currentLineIndex(in: lines, at: position))
    }
  }
}

// The current line plus the next one dimmed below it. Lines keep their index as identity,
// so on each change the next line slides up into place instead of being replaced.
private struct LyricWindow: View {
  let lines: [LyricLine]
  let current: Int?
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @AppStorage(Preferences.fontFamily.key) private var fontFamily = Preferences.fontFamily.defaultValue
  @AppStorage(Preferences.fontColor.key) private var fontColor = Preferences.fontColor.defaultValue
  @AppStorage(Preferences.fontSize.key) private var fontSize = Preferences.fontSize.defaultValue

  private var font: Font {
    fontFamily.isEmpty ? .system(size: fontSize, weight: .bold) : .custom(fontFamily, size: fontSize).bold()
  }

  private var visible: [Int] {
    // Before the first line, preview it dimmed.
    let first = current ?? -1
    return [first, first + 1].filter(lines.indices.contains)
  }

  var body: some View {
    VStack(spacing: 4) {
      ForEach(visible, id: \.self) { index in
        let isCurrent = index == current
        Text(lines[index].text)
          .font(font)
          .lineLimit(1)
          .minimumScaleFactor(0.5)
          .foregroundStyle(Color(hex: fontColor) ?? .white)
          // Legible over any wallpaper or app without a backing plate.
          .shadow(color: .black.opacity(0.6), radius: 4)
          .scaleEffect(isCurrent ? 1 : 0.75)
          .opacity(isCurrent ? 1 : 0.45)
          .transition(
            reduceMotion
              ? .opacity
              : .asymmetric(
                insertion: .move(edge: .bottom).combined(with: .opacity),
                removal: .move(edge: .top).combined(with: .opacity)
              )
          )
      }
    }
    .frame(maxWidth: .infinity)
    // Strong ease-in-out: lines move on screen rather than enter from nowhere.
    .animation(
      reduceMotion ? .easeInOut(duration: 0.2) : .timingCurve(0.77, 0, 0.175, 1, duration: 0.25),
      value: current
    )
  }
}

#Preview {
  let payload = NowPlayingPayload(
    bundleIdentifier: "com.spotify.client", parentApplicationBundleIdentifier: nil, title: "Comatose",
    artist: "Skillet",
    album: "Comatose", durationMicros: 230_000_000, elapsedTimeMicros: 27_000_000,
    timestampEpochMicros: Date.now.timeIntervalSince1970 * 1_000_000, playbackRate: 1, playing: true
  )
  let lines = LRCParser.parse(
    """
    [00:28.43] I hate feeling like this
    [00:31.36] I'm so tired of trying to fight this
    [00:34.17] I'm asleep and all I dream of
    [00:36.99] Is waking to you
    """)
  SyncedLyricsView(nowPlaying: NowPlaying(payload: payload)!, lines: lines, trackOffset: 0)
    .padding()
}
