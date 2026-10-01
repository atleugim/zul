import Testing

@testable import Zul

struct LRCParserTests {
  @Test func parsesTimedLines() {
    let lines = LRCParser.parse("[00:28.43] I hate feeling like this\n[00:31.36] I'm so tired of trying to fight this")

    #expect(
      lines == [
        LyricLine(time: 28.43, text: "I hate feeling like this"),
        LyricLine(time: 31.36, text: "I'm so tired of trying to fight this"),
      ])
  }

  @Test func expandsMultipleTimestampsInOrder() {
    let lines = LRCParser.parse("[00:10.00]Verse\n[00:05.00][00:20.00]Chorus")

    #expect(lines.map(\.time) == [5, 10, 20])
    #expect(lines.map(\.text) == ["Chorus", "Verse", "Chorus"])
  }

  @Test func appliesOffset() {
    let lines = LRCParser.parse("[offset:+500]\n[00:10.00]Line")

    #expect(lines == [LyricLine(time: 9.5, text: "Line")])
  }

  @Test func appliesNegativeOffset() {
    let lines = LRCParser.parse("[00:10.00]Line\n[offset:-250]")

    #expect(lines == [LyricLine(time: 10.25, text: "Line")])
  }

  @Test func keepsEmptyTimedLines() {
    let lines = LRCParser.parse("[00:10.00]Line\n[00:15.00]\n\n[00:20.00]Next")

    #expect(lines.map(\.text) == ["Line", "", "Next"])
  }

  @Test func ignoresMetadataTags() {
    let lines = LRCParser.parse("[ar:Skillet]\n[ti:Comatose]\n[length: 03:50]\n[00:10.00]Line")

    #expect(lines == [LyricLine(time: 10, text: "Line")])
  }

  @Test func acceptsTimestampVariants() {
    let lines = LRCParser.parse("[01:02.345]Millis\r\n[01:03]Seconds\r\n[01:04:50]Colon")

    #expect(lines.map(\.time) == [62.345, 63, 64.5])
  }
}
