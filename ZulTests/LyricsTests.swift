import Testing

@testable import Zul

struct LyricsTests {
  @Test func parsesSynced() {
    #expect(Lyrics(record: .fixture(synced: "[00:01.00]Line")) == .synced([LyricLine(time: 1, text: "Line")]))
  }

  @Test func unsyncedIsNotFound() {
    #expect(Lyrics(record: .fixture(synced: nil)) == .notFound)
    #expect(Lyrics(record: .fixture(synced: "")) == .notFound)
  }

  @Test func missingIsNotFound() {
    #expect(Lyrics(record: nil) == .notFound)
  }
}
