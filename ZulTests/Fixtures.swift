import Foundation

@testable import Zul

extension NowPlaying {
  // A playing track; tests override only the fields they're about.
  static func fixture(
    bundleID: String = "com.spotify.client",
    title: String = "Song",
    artist: String = "Artist",
    album: String = "",
    durationMicros: Double = 200_000_000
  ) -> NowPlaying {
    let payload = NowPlayingPayload(
      bundleIdentifier: bundleID, parentApplicationBundleIdentifier: nil, title: title, artist: artist, album: album,
      durationMicros: durationMicros, elapsedTimeMicros: nil, timestampEpochMicros: nil, playbackRate: nil,
      playing: true
    )
    return NowPlaying(payload: payload)!
  }
}

extension LyricsRecord {
  static func fixture(
    id: Int = 1,
    title: String = "Song",
    duration: TimeInterval = 200,
    synced: String? = "[00:01.00]Line"
  ) -> LyricsRecord {
    LyricsRecord(
      id: id, trackName: title, artistName: "Artist", albumName: nil, duration: duration, syncedLyrics: synced)
  }
}
