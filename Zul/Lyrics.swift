import Foundation

// Only synced lyrics can follow the song, so anything else counts as not found.
enum Lyrics: Equatable {
  case synced([LyricLine])
  case notFound

  init(record: LyricsRecord?) {
    let lines = record?.syncedLyrics.map { LRCParser.parse($0) } ?? []
    self = lines.isEmpty ? .notFound : .synced(lines)
  }
}
