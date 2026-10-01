import Foundation

struct NowPlaying: Equatable {
  let title: String
  let artist: String
  let album: String
  // Nil when the player doesn't report one (some players and browsers send 0).
  let duration: TimeInterval?
  let elapsed: TimeInterval
  let timestamp: Date
  let playbackRate: Double
  let isPlaying: Bool
  let sourceBundleID: String

  init?(payload: NowPlayingPayload) {
    guard let title = payload.title, let bundleID = payload.bundleIdentifier else { return nil }
    let isPlaying = payload.playing ?? false
    let durationMicros = payload.durationMicros ?? 0

    self.title = title
    self.artist = payload.artist ?? ""
    self.album = payload.album ?? ""
    self.duration = durationMicros > 0 ? durationMicros / 1_000_000 : nil
    self.elapsed = (payload.elapsedTimeMicros ?? 0) / 1_000_000
    self.timestamp = payload.timestampEpochMicros.map { Date(timeIntervalSince1970: $0 / 1_000_000) } ?? .now
    // Spotify sends a null rate while switching from paused to playing.
    self.playbackRate = isPlaying ? payload.playbackRate ?? 1 : 0
    self.isPlaying = isPlaying
    // Browsers report a helper process (e.g. com.apple.WebKit.GPU) and put the real app in the parent.
    self.sourceBundleID = payload.parentApplicationBundleIdentifier ?? bundleID
  }

  // The adapter only emits on state changes, so the position is extrapolated from the last one.
  func position(at date: Date = .now) -> TimeInterval {
    let position = elapsed + date.timeIntervalSince(timestamp) * playbackRate
    guard let duration else { return position }
    return min(position, duration)
  }

  // Inverse of position(at:): when playback reaches `position`. Nil while paused, since it never will.
  func date(atPosition position: TimeInterval) -> Date? {
    guard playbackRate > 0 else { return nil }
    return timestamp.addingTimeInterval((position - elapsed) / playbackRate)
  }
}
