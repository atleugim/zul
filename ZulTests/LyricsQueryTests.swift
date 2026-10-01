import Testing

@testable import Zul

struct LyricsQueryTests {
  @Test func keepsMusicAppMetadata() {
    let query = LyricsQuery(track: .fixture(title: "Comatose - Remastered", artist: "Skillet"))

    #expect(query.title == "Comatose - Remastered")
    #expect(query.artist == "Skillet")
  }

  @Test func splitsBrowserTitleAndDropsNoise() {
    let query = LyricsQuery(
      track: .fixture(
        bundleID: "com.google.Chrome", title: "Skillet - Comatose (Official Video) [4K]", artist: "SkilletVEVO"
      ))

    #expect(query.title == "Comatose")
    #expect(query.artist == "Skillet")
  }

  @Test func keepsNonNoiseParentheses() {
    let query = LyricsQuery(
      track: .fixture(bundleID: "com.apple.Safari", title: "Katy Perry - Roar (Acoustic)", artist: ""))

    #expect(query.title == "Roar (Acoustic)")
  }

  @Test func ignoresBrowserChannelName() {
    let query = LyricsQuery(
      track: .fixture(bundleID: "com.apple.Safari", title: "Rust vs Go", artist: "Algorithmswithpeter"))

    #expect(query.artist == "")
  }

  @Test func usesTopicChannelAsArtist() {
    let query = LyricsQuery(
      track: .fixture(bundleID: "com.google.Chrome", title: "Comatose", artist: "Skillet - Topic"))

    #expect(query.artist == "Skillet")
  }

  @Test func cleansTaglessFileName() {
    let query = LyricsQuery(track: .fixture(bundleID: "com.apple.Music", title: "05 Comatose.mp3", artist: ""))

    #expect(query.title == "Comatose")
    #expect(query.artist == "")
  }

  @Test func splitsArtistFromFileName() {
    let query = LyricsQuery(track: .fixture(bundleID: "com.apple.Music", title: "Skillet - Comatose.m4a", artist: ""))

    #expect(query.title == "Comatose")
    #expect(query.artist == "Skillet")
  }

  @Test func dropsImplausibleDuration() {
    let query = LyricsQuery(track: .fixture(bundleID: "com.apple.Safari", title: "Video", durationMicros: 557_278))

    #expect(query.duration == nil)
  }
}
