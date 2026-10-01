import Foundation

extension Bundle {
  var shortVersion: String {
    infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
  }
}
