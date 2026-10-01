import Foundation
import Testing

@testable import Zul

@MainActor
struct StreamMessageTests {
  @Test func decodesPlayingTrack() throws {
    let line =
      #"{"type":"data","diff":false,"payload":{"bundleIdentifier":"com.spotify.client","title":"Comatose","artist":"Skillet","album":"Comatose","durationMicros":230427000,"elapsedTimeMicros":20009000,"timestampEpochMicros":1790794625806810,"playbackRate":1,"playing":true}}"#
    let payload = try JSONDecoder().decode(StreamMessage.self, from: Data(line.utf8)).payload

    #expect(payload.bundleIdentifier == "com.spotify.client")
    #expect(payload.title == "Comatose")
    #expect(payload.durationMicros == 230_427_000)
    #expect(payload.timestampEpochMicros == 1_790_794_625_806_810)
    #expect(payload.playing == true)
  }

  @Test func decodesNothingPlaying() throws {
    let line = #"{"type":"data","diff":false,"payload":{}}"#
    let payload = try JSONDecoder().decode(StreamMessage.self, from: Data(line.utf8)).payload

    #expect(payload.title == nil)
  }

  @Test func decodesNullPlaybackRate() throws {
    let line =
      #"{"type":"data","diff":false,"payload":{"bundleIdentifier":"com.spotify.client","title":"Comatose","playbackRate":null,"playing":true}}"#
    let payload = try JSONDecoder().decode(StreamMessage.self, from: Data(line.utf8)).payload

    #expect(payload.playbackRate == nil)
  }
}

// Built from the adapter's JSON so the tests also pin down the wire format.
@MainActor
struct NowPlayingTests {
  private func nowPlaying(_ json: String) throws -> NowPlaying? {
    NowPlaying(payload: try JSONDecoder().decode(NowPlayingPayload.self, from: Data(json.utf8)))
  }

  @Test func mapsSpotifyTrack() throws {
    let nowPlaying = try #require(
      try nowPlaying(
        #"{"bundleIdentifier":"com.spotify.client","title":"Comatose","artist":"Skillet","album":"Comatose","durationMicros":230427000,"elapsedTimeMicros":20009000,"timestampEpochMicros":1790794625806810,"playbackRate":1,"playing":true}"#
      ))

    #expect(nowPlaying.duration == 230.427)
    #expect(nowPlaying.elapsed == 20.009)
    #expect(nowPlaying.timestamp == Date(timeIntervalSince1970: 1_790_794_625.806810))
    #expect(nowPlaying.playbackRate == 1)
    #expect(nowPlaying.sourceBundleID == "com.spotify.client")
  }

  @Test func nothingPlayingIsNil() throws {
    #expect(try nowPlaying("{}") == nil)
  }

  @Test func nullRateWhilePlayingDefaultsToOne() throws {
    let nowPlaying = try #require(
      try nowPlaying(
        #"{"bundleIdentifier":"com.spotify.client","title":"Comatose","playbackRate":null,"playing":true}"#))

    #expect(nowPlaying.playbackRate == 1)
  }

  @Test func pausedHasZeroRate() throws {
    let nowPlaying = try #require(
      try nowPlaying(#"{"bundleIdentifier":"com.spotify.client","title":"Comatose","playbackRate":1,"playing":false}"#))

    #expect(nowPlaying.playbackRate == 0)
  }

  @Test func zeroDurationIsNil() throws {
    let nowPlaying = try #require(
      try nowPlaying(
        #"{"bundleIdentifier":"com.example.player","title":"Comatose","durationMicros":0,"playing":true}"#)
    )

    #expect(nowPlaying.duration == nil)
  }

  @Test func positionAdvancesWhilePlaying() throws {
    let nowPlaying = try #require(
      try nowPlaying(
        #"{"bundleIdentifier":"com.spotify.client","title":"Comatose","durationMicros":230000000,"elapsedTimeMicros":20000000,"timestampEpochMicros":1000000000000000,"playbackRate":1,"playing":true}"#
      ))

    #expect(nowPlaying.position(at: Date(timeIntervalSince1970: 1_000_000_005)) == 25)
  }

  @Test func positionStaysWhilePaused() throws {
    let nowPlaying = try #require(
      try nowPlaying(
        #"{"bundleIdentifier":"com.spotify.client","title":"Comatose","durationMicros":230000000,"elapsedTimeMicros":20000000,"timestampEpochMicros":1000000000000000,"playbackRate":1,"playing":false}"#
      ))

    #expect(nowPlaying.position(at: Date(timeIntervalSince1970: 1_000_000_005)) == 20)
  }

  @Test func positionClampsToDuration() throws {
    let nowPlaying = try #require(
      try nowPlaying(
        #"{"bundleIdentifier":"com.spotify.client","title":"Comatose","durationMicros":230000000,"elapsedTimeMicros":220000000,"timestampEpochMicros":1000000000000000,"playbackRate":1,"playing":true}"#
      ))

    #expect(nowPlaying.position(at: Date(timeIntervalSince1970: 1_000_000_060)) == 230)
  }

  @Test func dateAtPositionInvertsPosition() throws {
    let nowPlaying = try #require(
      try nowPlaying(
        #"{"bundleIdentifier":"com.spotify.client","title":"Comatose","durationMicros":230000000,"elapsedTimeMicros":20000000,"timestampEpochMicros":1000000000000000,"playbackRate":1,"playing":true}"#
      )
    )
    let date = try #require(nowPlaying.date(atPosition: 25))

    #expect(date == Date(timeIntervalSince1970: 1_000_000_005))
    #expect(nowPlaying.position(at: date) == 25)
  }

  @Test func dateAtPositionIsNilWhilePaused() throws {
    let nowPlaying = try #require(
      try nowPlaying(#"{"bundleIdentifier":"com.spotify.client","title":"Comatose","playbackRate":1,"playing":false}"#)
    )

    #expect(nowPlaying.date(atPosition: 25) == nil)
  }

  @Test func browserUsesParentBundleID() throws {
    let nowPlaying = try #require(
      try nowPlaying(
        #"{"bundleIdentifier":"com.apple.WebKit.GPU","parentApplicationBundleIdentifier":"com.apple.Safari","title":"Video","playing":false}"#
      ))

    #expect(nowPlaying.sourceBundleID == "com.apple.Safari")
  }
}
