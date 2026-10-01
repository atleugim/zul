import Foundation

struct LyricLine: Equatable {
  let time: TimeInterval
  let text: String
}

enum LRCParser {
  static func parse(_ lrc: String) -> [LyricLine] {
    var offset: TimeInterval = 0
    var lines: [LyricLine] = []

    for rawLine in lrc.split(whereSeparator: \.isNewline) {
      if let match = rawLine.wholeMatch(of: #/\s*\[offset:\s*([+-]?\d+)\s*\]\s*/#.ignoresCase()) {
        offset = Double(match.1)! / 1000
        continue
      }
      // A line can carry several timestamps when it repeats, e.g. "[00:12.00][01:30.00]Chorus".
      var rest = rawLine[...]
      var times: [TimeInterval] = []
      while let match = rest.prefixMatch(of: #/\s*\[(\d+):(\d+(?:[.:]\d+)?)\]/#) {
        times.append(Double(match.1)! * 60 + Double(match.2.replacing(":", with: "."))!)
        rest = rest[match.range.upperBound...]
      }
      // Timestamps with empty text are kept: they mark where the previous line ends.
      let text = rest.trimmingCharacters(in: .whitespaces)
      lines += times.map { LyricLine(time: $0, text: text) }
    }

    // A positive offset makes lyrics appear sooner.
    return
      lines
      .map { LyricLine(time: $0.time - offset, text: $0.text) }
      .sorted { $0.time < $1.time }
  }
}
