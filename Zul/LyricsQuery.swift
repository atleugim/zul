import Foundation

struct LyricsQuery: Equatable {
  let title: String
  let artist: String
  let album: String
  let duration: TimeInterval?
}

extension LyricsQuery {
  static let browserBundleIDs: Set<String> = [
    "com.apple.Safari",
    "com.google.Chrome",
    "org.mozilla.firefox",
    "com.microsoft.edgemac",
    "com.brave.Browser",
    "company.thebrowser.Browser",
    "com.operasoftware.Opera",
    "app.zen-browser.zen",
    "net.imput.helium",
  ]

  // Tagless local files report the file name, e.g. "05 Comatose.mp3".
  private static let taglessFileName = #/(?:\d{2}[\s.\-]+)?(.+)\.(?:mp3|m4a|flac|wav|aiff?|aac|ogg|opus)/#.ignoresCase()
  // Video title decorations, e.g. "(Official Video)" or "[4K]"; other parentheses like "(Acoustic)" stay.
  private static let browserNoise =
    #/\s*[(\[][^)\]]*\b(?:official|video|audio|lyrics?|visuali[sz]er|4k|hd|m\/?v)\b[^)\]]*[)\]]/#
    .ignoresCase()
  // "Artist - Song", with a hyphen, en dash or em dash.
  private static let artistDashTitle = #/(.+?)\s+[-–—]\s+(.+)/#
  // YouTube's auto-generated "Artist - Topic" channels name the artist; other channel names don't.
  private static let topicChannelSuffix = " - Topic"

  init(track: NowPlaying) {
    var title = track.title
    var artist = track.artist

    if let match = title.wholeMatch(of: Self.taglessFileName) {
      title = String(match.1)
    }
    if Self.browserBundleIDs.contains(track.sourceBundleID) {
      title = title.replacing(Self.browserNoise, with: "")
      artist = artist.hasSuffix(Self.topicChannelSuffix) ? String(artist.dropLast(Self.topicChannelSuffix.count)) : ""
    }
    if artist.isEmpty, let match = title.wholeMatch(of: Self.artistDashTitle) {
      artist = String(match.1)
      title = String(match.2)
    }

    self.title = title.trimmingCharacters(in: .whitespaces)
    self.artist = artist.trimmingCharacters(in: .whitespaces)
    self.album = track.album
    // Safari has reported 0.557 s for a video; no song is that short, and it would skew matching.
    self.duration = track.duration.flatMap { $0 >= 30 ? $0 : nil }
  }
}
