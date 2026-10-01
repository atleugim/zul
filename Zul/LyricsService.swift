import Foundation

struct LyricsRecord: Codable, Equatable {
  let id: Int
  let trackName: String
  let artistName: String
  let albumName: String?
  let duration: TimeInterval
  // Plain lyrics and the instrumental flag aren't decoded: without timestamps there's
  // nothing to show, and leaving them out keeps them out of the cache too.
  let syncedLyrics: String?

  var hasSyncedLyrics: Bool {
    !(syncedLyrics ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }
}

enum LRCLIBError: Error, Equatable {
  // LRCLIB requires clients to wait this long before any further request.
  case rateLimited(retryAfter: TimeInterval)
}

struct LyricsService {
  // LRCLIB requires clients to identify themselves.
  private static let userAgent = "Zul v\(Bundle.main.shortVersion) (\(Repository.url.absoluteString))"

  let cache: LyricsCache
  // Swappable so tests can exercise the get → search fallback and caching without the network.
  var load: (URLRequest) async throws -> (Data, URLResponse) = { try await URLSession.shared.data(for: $0) }

  static func getURL(for query: LyricsQuery) -> URL? {
    guard let duration = query.duration, !query.artist.isEmpty else { return nil }
    var components = URLComponents(string: "https://lrclib.net/api/get")!
    components.queryItems = [
      URLQueryItem(name: "track_name", value: query.title),
      URLQueryItem(name: "artist_name", value: query.artist),
      URLQueryItem(name: "duration", value: String(Int(duration.rounded()))),
    ]
    if !query.album.isEmpty {
      components.queryItems?.append(URLQueryItem(name: "album_name", value: query.album))
    }
    return components.url
  }

  static func searchURL(for query: LyricsQuery) -> URL {
    var components = URLComponents(string: "https://lrclib.net/api/search")!
    components.queryItems =
      query.artist.isEmpty
      ? [URLQueryItem(name: "q", value: query.title)]
      : [URLQueryItem(name: "track_name", value: query.title), URLQueryItem(name: "artist_name", value: query.artist)]
    return components.url!
  }

  static func bestMatch(in results: [LyricsRecord], duration: TimeInterval?) -> LyricsRecord? {
    // Filtered first, so an unsynced exact-length match can't hide a synced one a second off.
    let records = results.filter(\.hasSyncedLyrics)
    guard let duration else {
      // Search returns edits and covers of other lengths first; the length most uploads
      // agree on is likely the canonical version. Ties keep LRCLIB's relevance order.
      let counts = Dictionary(grouping: records) { $0.duration.rounded() }.mapValues(\.count)
      return records.max { counts[$0.duration.rounded()]! < counts[$1.duration.rounded()]! }
    }
    return records.min { abs($0.duration - duration) < abs($1.duration - duration) }
  }

  func lyrics(for track: NowPlaying) async throws -> LyricsRecord? {
    let query = LyricsQuery(track: track)
    if let entry = cache.entry(for: query) { return entry.record }
    // Errors propagate uncached, so a 503 is retried on the next play.
    let record = try await remoteLyrics(for: query)
    cache.store(LyricsCache.Entry(record: record, fetchedAt: .now), for: query)
    return record
  }

  private func remoteLyrics(for query: LyricsQuery) async throws -> LyricsRecord? {
    if let url = Self.getURL(for: query), let record: LyricsRecord = try await fetch(url), record.hasSyncedLyrics {
      return record
    }
    let records: [LyricsRecord] = try await fetch(Self.searchURL(for: query)) ?? []
    return Self.bestMatch(in: records, duration: query.duration)
  }

  private func fetch<T: Decodable>(_ url: URL) async throws -> T? {
    var request = URLRequest(url: url)
    request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
    let (data, response) = try await load(request)
    let http = response as? HTTPURLResponse
    let status = http?.statusCode
    if status == 404 { return nil }
    if status == 429 {
      // A minute is a cautious stand-in when the header is missing or an HTTP date.
      let retryAfter = http?.value(forHTTPHeaderField: "Retry-After").flatMap(TimeInterval.init) ?? 60
      throw LRCLIBError.rateLimited(retryAfter: retryAfter)
    }
    // LRCLIB also answers 503 under load; throwing keeps it from being mistaken for "not found".
    guard status == 200 else { throw URLError(.badServerResponse) }
    return try JSONDecoder().decode(T.self, from: data)
  }
}
