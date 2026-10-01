import SwiftUI

// @AppStorage can't store a Color, so the font color is persisted as "#RRGGBB".
extension Color {
  init?(hex: String) {
    guard hex.count == 7, hex.hasPrefix("#"), let value = UInt32(hex.dropFirst(), radix: 16) else { return nil }
    self.init(
      red: Double(value >> 16 & 0xFF) / 255,
      green: Double(value >> 8 & 0xFF) / 255,
      blue: Double(value & 0xFF) / 255
    )
  }

  var hex: String {
    let color = NSColor(self).usingColorSpace(.sRGB) ?? .white
    let components = [color.redComponent, color.greenComponent, color.blueComponent]
    return "#" + components.map { String(format: "%02X", Int(($0 * 255).rounded())) }.joined()
  }
}
