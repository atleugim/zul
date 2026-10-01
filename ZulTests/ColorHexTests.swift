import SwiftUI
import Testing

@testable import Zul

struct ColorHexTests {
  @Test func roundTrips() {
    #expect(Color(hex: "#1E90FF")?.hex == "#1E90FF")
  }

  @Test func rejectsMalformed() {
    #expect(Color(hex: "1E90FF") == nil)
    #expect(Color(hex: "#1E90") == nil)
    #expect(Color(hex: "#GGGGGG") == nil)
  }
}
