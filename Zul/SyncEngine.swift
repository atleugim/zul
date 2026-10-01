import Foundation

enum SyncEngine {
  // A song has a few dozen lines, so a scan is enough. Expects lines sorted by time, as LRCParser returns them.
  static func currentLineIndex(in lines: [LyricLine], at position: TimeInterval) -> Int? {
    lines.lastIndex { $0.time <= position }
  }
}
