import CryptoKit
import Foundation

struct LyricsCache {
  struct Entry: Codable, Equatable {
    // Nil records that no synced lyrics were found, so LRCLIB isn't asked again on every play.
    var record: LyricsRecord?
    var fetchedAt: Date
    var offset: TimeInterval = 0
  }

  // LRCLIB keeps growing, so a miss is retried weekly in case synced lyrics were added.
  static let notFoundTTL: TimeInterval = 7 * 24 * 60 * 60

  let directory: URL

  init(
    directory: URL = URL.cachesDirectory.appending(path: Bundle.main.bundleIdentifier ?? "Zul").appending(
      path: "lyrics")
  ) {
    self.directory = directory
  }

  static func key(for query: LyricsQuery) -> String {
    let duration = query.duration.map { String(Int($0.rounded())) } ?? "-"
    let identity = "\(query.artist)\n\(query.title)\n\(duration)".lowercased()
    return SHA256.hash(data: Data(identity.utf8)).map { String(format: "%02x", $0) }.joined()
  }

  func entry(for query: LyricsQuery, now: Date = .now) -> Entry? {
    guard
      let data = try? Data(contentsOf: url(for: query)),
      let entry = try? JSONDecoder().decode(Entry.self, from: data)
    else { return nil }
    // Also covers entries cached with unsynced lyrics before only synced ones counted.
    if entry.record?.hasSyncedLyrics != true, now.timeIntervalSince(entry.fetchedAt) > Self.notFoundTTL { return nil }
    return entry
  }

  func store(_ entry: Entry, for query: LyricsQuery) {
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try? JSONEncoder().encode(entry).write(to: url(for: query), options: .atomic)
  }

  private func url(for query: LyricsQuery) -> URL {
    directory.appending(path: "\(Self.key(for: query)).json")
  }
}
