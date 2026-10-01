import Foundation

struct Release: Decodable, Equatable {
  let tagName: String
  let htmlUrl: URL
}

enum UpdateChecker {
  static func latestRelease() async throws -> Release {
    let url = URL(string: "https://api.github.com/repos/atleugim/zul/releases/latest")!
    let (data, _) = try await URLSession.shared.data(from: url)
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    return try decoder.decode(Release.self, from: data)
  }

  // Compares dotted numeric versions, so "v0.10.0" is newer than "0.9.0". Missing parts count as 0.
  static func isVersion(_ tag: String, newerThan current: String) -> Bool {
    func parts(_ version: String) -> [Int] {
      version.trimmingPrefix("v").split(separator: ".").map { Int($0) ?? 0 }
    }
    let new = parts(tag)
    let old = parts(current)
    for index in 0..<max(new.count, old.count) {
      let newPart = index < new.count ? new[index] : 0
      let oldPart = index < old.count ? old[index] : 0
      if newPart != oldPart { return newPart > oldPart }
    }
    return false
  }
}
