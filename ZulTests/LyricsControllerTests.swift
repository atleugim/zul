import Foundation
import Testing

@testable import Zul

@MainActor
struct LyricsControllerTests {
  @Test func lateResponseForPreviousTrackIsDropped() async {
    let controller = LyricsController { track in
      // A detached sleep ignores cancellation, so the old track's response arrives after the new one.
      if track.title == "Old" { await Task.detached { try? await Task.sleep(for: .milliseconds(100)) }.value }
      return .fixture(title: track.title, synced: "[00:01.00]\(track.title)")
    }

    let old = controller.update(for: .fixture(title: "Old"))
    let new = controller.update(for: .fixture(title: "New"))
    await old?.value
    await new?.value

    #expect(controller.lyrics == .synced([LyricLine(time: 1, text: "New")]))
  }

  @Test func sameTrackDoesNotRefetch() {
    let controller = LyricsController { _ in nil }

    #expect(controller.update(for: .fixture()) != nil)
    #expect(controller.update(for: .fixture()) == nil)
  }

  @Test func trackChangeClearsPreviousLyrics() async {
    let controller = LyricsController { _ in .fixture() }
    await controller.update(for: .fixture())?.value

    controller.update(for: nil)

    #expect(controller.lyrics == nil)
  }

  @Test func emptyResultIsNotFound() async {
    let controller = LyricsController { _ in nil }
    await controller.update(for: .fixture())?.value

    #expect(controller.lyrics == .notFound)
  }

  @Test func retriesAfterFailure() async {
    var calls = 0
    let controller = LyricsController(
      fetch: { _ in
        calls += 1
        if calls == 1 { throw URLError(.badServerResponse) }
        return .fixture()
      }, retryDelay: .zero)
    await controller.update(for: .fixture())?.value

    #expect(controller.lyrics == .synced([LyricLine(time: 1, text: "Line")]))
  }

  @Test func waitsOutRateLimitBeforeRetrying() async {
    var callTimes: [Date] = []
    let controller = LyricsController(
      fetch: { _ in
        callTimes.append(.now)
        if callTimes.count == 1 { throw LRCLIBError.rateLimited(retryAfter: 0.3) }
        return .fixture()
      },
      retryDelay: .zero
    )
    await controller.update(for: .fixture())?.value

    #expect(controller.lyrics == .synced([LyricLine(time: 1, text: "Line")]))
    #expect(callTimes.count == 2)
    #expect(callTimes[1].timeIntervalSince(callTimes[0]) >= 0.3)
  }

  @Test func rateLimitAlsoDelaysTheNextTrack() async {
    var callTimes: [Date] = []
    let controller = LyricsController(
      fetch: { track in
        callTimes.append(.now)
        if track.title == "First" { throw LRCLIBError.rateLimited(retryAfter: 0.3) }
        return .fixture()
      },
      retryDelay: .zero
    )
    controller.update(for: .fixture(title: "First"))
    // Let the first lookup hit the rate limit before the track changes.
    try? await Task.sleep(for: .milliseconds(50))
    await controller.update(for: .fixture(title: "Second"))?.value

    #expect(callTimes.count == 2)
    #expect(callTimes[1].timeIntervalSince(callTimes[0]) >= 0.3)
  }

  @Test func sameTrackRefetchesAfterFailedRetries() async {
    let controller = LyricsController(fetch: { _ in throw URLError(.badServerResponse) }, retryDelay: .zero)
    await controller.update(for: .fixture())?.value

    #expect(controller.update(for: .fixture()) != nil)
  }

  @Test func failedLookupIsNilNotNotFound() async {
    let controller = LyricsController(fetch: { _ in throw URLError(.badServerResponse) }, retryDelay: .zero)
    await controller.update(for: .fixture())?.value

    #expect(controller.lyrics == nil)
  }
}

@MainActor
struct TrackOffsetTests {
  private let cache = LyricsCache(directory: URL.temporaryDirectory.appending(path: UUID().uuidString))

  private func storeEntry(for track: NowPlaying) {
    cache.store(
      LyricsCache.Entry(record: .fixture(title: track.title), fetchedAt: .now), for: LyricsQuery(track: track))
  }

  @Test func persistsAcrossControllers() {
    let song = NowPlaying.fixture(title: "Song")
    storeEntry(for: song)

    let first = LyricsController(fetch: { _ in nil }, cache: cache)
    first.update(for: song)
    first.setTrackOffset(-0.75)

    let second = LyricsController(fetch: { _ in nil }, cache: cache)
    second.update(for: song)

    #expect(second.trackOffset == -0.75)
  }

  @Test func resetsOnTrackChange() {
    let song = NowPlaying.fixture(title: "Song")
    let other = NowPlaying.fixture(title: "Other")
    storeEntry(for: song)
    storeEntry(for: other)

    let controller = LyricsController(fetch: { _ in nil }, cache: cache)
    controller.update(for: song)
    controller.setTrackOffset(1)
    controller.update(for: other)

    #expect(controller.trackOffset == 0)
  }

  @Test func ignoredWithoutCacheEntry() {
    let controller = LyricsController(fetch: { _ in nil }, cache: cache)
    controller.update(for: .fixture(title: "Uncached"))
    controller.setTrackOffset(1)

    #expect(controller.trackOffset == 0)
  }
}
