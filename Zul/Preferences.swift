import Foundation

struct Preference<Value> {
  let key: String
  let defaultValue: Value
}

// Every UserDefaults key with its default, so views and the panel can't drift apart.
enum Preferences {
  static let overlayVisible = Preference(key: "overlayVisible", defaultValue: true)
  static let overlayOpacity = Preference(key: "overlayOpacity", defaultValue: 1.0)
  static let overlayPosition = Preference(key: "overlayPosition", defaultValue: OverlayPosition.bottom)
  // NSStringFromPoint of the dragged origin; only read when the position is .custom.
  static let overlayOrigin = Preference<String?>(key: "overlayOrigin", defaultValue: nil)
  static let showOnAllSpaces = Preference(key: "showOnAllSpaces", defaultValue: true)
  // Empty means the system font.
  static let fontFamily = Preference(key: "fontFamily", defaultValue: "")
  static let fontColor = Preference(key: "fontColor", defaultValue: "#FFFFFF")
  static let fontSize = Preference(key: "fontSize", defaultValue: 28.0)
  static let globalOffset = Preference<TimeInterval>(key: "globalOffset", defaultValue: 0)
}
