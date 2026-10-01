import Foundation
import Testing

@testable import Zul

struct LyricsServiceURLTests {
  private func query(_ url: URL?) throws -> [String: String] {
    let url = try #require(url)
    let items = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
    return Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
  }

  @Test func getURLIncludesAllFields() throws {
    let url = LyricsService.getURL(
      for: LyricsQuery(title: "Comatose", artist: "Skillet", album: "Comatose", duration: 230.427))

    #expect(
      try query(url) == [
        "track_name": "Comatose", "artist_name": "Skillet", "album_name": "Comatose", "duration": "230",
      ])
  }

  @Test func getURLOmitsEmptyAlbum() throws {
    let url = LyricsService.getURL(for: LyricsQuery(title: "Comatose", artist: "Skillet", album: "", duration: 230.427))

    #expect(try query(url)["album_name"] == nil)
  }

  @Test func getURLNeedsDuration() {
    #expect(
      LyricsService.getURL(
        for: LyricsQuery(title: "The One That Got Away", artist: "Katy Perry", album: "", duration: nil)) == nil)
  }

  @Test func getURLNeedsArtist() {
    #expect(LyricsService.getURL(for: LyricsQuery(title: "Comatose", artist: "", album: "", duration: 230.478)) == nil)
  }

  @Test func searchURLUsesFreeTextWithoutArtist() {
    let url = LyricsService.searchURL(for: LyricsQuery(title: "Comatose", artist: "", album: "", duration: nil))
    let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems

    #expect(items == [URLQueryItem(name: "q", value: "Comatose")])
  }
}

struct LyricsBestMatchTests {
  @Test func skipsUnsyncedEvenIfCloser() {
    let records: [LyricsRecord] = [.fixture(id: 1, duration: 227, synced: nil), .fixture(id: 2, duration: 228)]

    #expect(LyricsService.bestMatch(in: records, duration: 227)?.id == 2)
  }

  @Test func onlyUnsyncedHasNoMatch() {
    #expect(LyricsService.bestMatch(in: [.fixture(duration: 227, synced: nil)], duration: 227) == nil)
  }

  @Test func picksClosestDuration() {
    let records: [LyricsRecord] = [
      .fixture(id: 1, duration: 128), .fixture(id: 2, duration: 227), .fixture(id: 3, duration: 262),
    ]

    #expect(LyricsService.bestMatch(in: records, duration: 226.4)?.id == 2)
  }

  @Test func withoutDurationPicksMostCommonLength() {
    let records: [LyricsRecord] = [
      .fixture(id: 1, duration: 128), .fixture(id: 2, duration: 227), .fixture(id: 3, duration: 227),
      .fixture(id: 4, duration: 246),
    ]

    #expect(LyricsService.bestMatch(in: records, duration: nil)?.id == 2)
  }

  @Test func withoutDurationTieKeepsRelevanceOrder() {
    let records: [LyricsRecord] = [.fixture(id: 1, duration: 128), .fixture(id: 2, duration: 227)]

    #expect(LyricsService.bestMatch(in: records, duration: nil)?.id == 1)
  }

  @Test func emptyResultsHaveNoMatch() {
    #expect(LyricsService.bestMatch(in: [], duration: 200) == nil)
  }
}

@MainActor
struct LyricsServiceFetchTests {
  private let cache = LyricsCache(directory: URL.temporaryDirectory.appending(path: UUID().uuidString))
  private let track = NowPlaying.fixture(
    title: "Comatose", artist: "Skillet", album: "Comatose", durationMicros: 230_427_000)
  private let synced =
    #"{"id":2,"trackName":"Comatose","artistName":"Skillet","albumName":"Comatose","duration":230,"syncedLyrics":"[00:28.43]I hate feeling like this"}"#
  private let unsynced =
    #"{"id":1,"trackName":"Comatose","artistName":"Skillet","albumName":"Comatose","duration":230,"syncedLyrics":null}"#

  private final class FakeLRCLIB {
    var responses: [String: (status: Int, body: String)]
    var requests: [String] = []
    let headers: [String: String]

    init(_ responses: [String: (status: Int, body: String)], headers: [String: String] = [:]) {
      self.responses = responses
      self.headers = headers
    }

    func load(_ request: URLRequest) throws -> (Data, URLResponse) {
      let url = try #require(request.url)
      requests.append(url.path)
      let (status, body) = responses[url.path] ?? (404, "")
      return (Data(body.utf8), HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: headers)!)
    }
  }

  private func service(_ lrclib: FakeLRCLIB) -> LyricsService {
    LyricsService(cache: cache, load: { try lrclib.load($0) })
  }

  @Test func getWithSyncedSkipsSearch() async throws {
    let lrclib = FakeLRCLIB(["/api/get": (200, synced)])
    let record = try await service(lrclib).lyrics(for: track)

    #expect(record?.id == 2)
    #expect(lrclib.requests == ["/api/get"])
  }

  @Test func unsyncedGetFallsBackToSearch() async throws {
    let lrclib = FakeLRCLIB(["/api/get": (200, unsynced), "/api/search": (200, "[\(unsynced),\(synced)]")])
    let record = try await service(lrclib).lyrics(for: track)

    #expect(record?.id == 2)
    #expect(lrclib.requests == ["/api/get", "/api/search"])
  }

  @Test func missingGetFallsBackToSearch() async throws {
    let lrclib = FakeLRCLIB(["/api/search": (200, "[\(synced)]")])
    let record = try await service(lrclib).lyrics(for: track)

    #expect(record?.id == 2)
  }

  @Test func foundLyricsAreServedFromCache() async throws {
    let lrclib = FakeLRCLIB(["/api/get": (200, synced)])
    _ = try await service(lrclib).lyrics(for: track)
    let record = try await service(lrclib).lyrics(for: track)

    #expect(record?.id == 2)
    #expect(lrclib.requests == ["/api/get"])
  }

  @Test func missIsCached() async throws {
    let lrclib = FakeLRCLIB(["/api/search": (200, "[\(unsynced)]")])
    _ = try await service(lrclib).lyrics(for: track)
    let record = try await service(lrclib).lyrics(for: track)

    #expect(record == nil)
    #expect(lrclib.requests == ["/api/get", "/api/search"])
  }

  @Test func rateLimitThrowsRetryAfter() async {
    let lrclib = FakeLRCLIB(["/api/get": (429, "")], headers: ["Retry-After": "30"])

    await #expect(throws: LRCLIBError.rateLimited(retryAfter: 30)) { try await service(lrclib).lyrics(for: track) }
  }

  @Test func rateLimitWithoutRetryAfterWaitsAMinute() async {
    let lrclib = FakeLRCLIB(["/api/get": (429, "")])

    await #expect(throws: LRCLIBError.rateLimited(retryAfter: 60)) { try await service(lrclib).lyrics(for: track) }
  }

  @Test func serverErrorThrowsAndIsNotCached() async throws {
    let lrclib = FakeLRCLIB(["/api/get": (503, "")])
    await #expect(throws: URLError.self) { try await service(lrclib).lyrics(for: track) }

    lrclib.responses = ["/api/get": (200, synced)]
    let record = try await service(lrclib).lyrics(for: track)

    #expect(record?.id == 2)
  }
}
