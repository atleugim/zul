import Testing

@testable import Zul

struct SyncEngineTests {
  private let lines = [
    LyricLine(time: 10, text: "First"),
    LyricLine(time: 15, text: ""),
    LyricLine(time: 20, text: "Second"),
  ]

  @Test func nilBeforeFirstLine() {
    #expect(SyncEngine.currentLineIndex(in: lines, at: 9.99) == nil)
  }

  @Test func lineStartsExactlyAtItsTime() {
    #expect(SyncEngine.currentLineIndex(in: lines, at: 10) == 0)
  }

  @Test func emptyLineEndsThePreviousOne() {
    #expect(SyncEngine.currentLineIndex(in: lines, at: 17) == 1)
  }

  @Test func lastLineHoldsUntilTheEnd() {
    #expect(SyncEngine.currentLineIndex(in: lines, at: 500) == 2)
  }

  @Test func noLinesHasNoCurrentLine() {
    #expect(SyncEngine.currentLineIndex(in: [], at: 10) == nil)
  }
}
