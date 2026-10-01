import Foundation
import Testing

@testable import Zul

struct LyricsCacheTests {
  private let cache = LyricsCache(directory: URL.temporaryDirectory.appending(path: UUID().uuidString))
  private let query = LyricsQuery(title: "Comatose", artist: "Skillet", album: "Comatose", duration: 230.427)
  private let record = LyricsRecord.fixture(id: 879007, title: "Comatose", duration: 230)

  @Test func roundTripsEntryWithOffset() {
    let entry = LyricsCache.Entry(record: record, fetchedAt: Date(timeIntervalSince1970: 1_000), offset: -0.5)
    cache.store(entry, for: query)

    #expect(cache.entry(for: query) == entry)
  }

  @Test func missingEntryIsNil() {
    #expect(cache.entry(for: query) == nil)
  }

  @Test func notFoundExpiresAfterTTL() {
    let fetchedAt = Date(timeIntervalSince1970: 1_000)
    cache.store(LyricsCache.Entry(record: nil, fetchedAt: fetchedAt), for: query)

    #expect(cache.entry(for: query, now: fetchedAt.addingTimeInterval(60)) != nil)
    #expect(cache.entry(for: query, now: fetchedAt.addingTimeInterval(LyricsCache.notFoundTTL + 1)) == nil)
  }

  @Test func foundLyricsNeverExpire() {
    let fetchedAt = Date(timeIntervalSince1970: 1_000)
    cache.store(LyricsCache.Entry(record: record, fetchedAt: fetchedAt), for: query)

    #expect(cache.entry(for: query, now: fetchedAt.addingTimeInterval(365 * 24 * 60 * 60))?.record == record)
  }

  @Test func keyIgnoresCaseAlbumAndSubsecondDuration() {
    let other = LyricsQuery(title: "COMATOSE", artist: "skillet", album: "Vital Signs", duration: 229.8)

    #expect(LyricsCache.key(for: query) == LyricsCache.key(for: other))
  }
}
