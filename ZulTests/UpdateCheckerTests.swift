import Foundation
import Testing

@testable import Zul

@MainActor
struct UpdateCheckerTests {
  @Test func newerPatchMinorAndMajor() {
    #expect(UpdateChecker.isVersion("v0.1.1", newerThan: "0.1.0"))
    #expect(UpdateChecker.isVersion("v0.2.0", newerThan: "0.1.9"))
    #expect(UpdateChecker.isVersion("v1.0.0", newerThan: "0.9.9"))
  }

  @Test func comparesNumericallyNotAlphabetically() {
    #expect(UpdateChecker.isVersion("v0.10.0", newerThan: "0.9.0"))
  }

  @Test func sameOrOlderIsNotNewer() {
    #expect(!UpdateChecker.isVersion("v0.1.0", newerThan: "0.1.0"))
    #expect(!UpdateChecker.isVersion("v0.1.0", newerThan: "0.2.0"))
  }

  @Test func missingPartsCountAsZero() {
    #expect(!UpdateChecker.isVersion("v0.2", newerThan: "0.2.0"))
    #expect(UpdateChecker.isVersion("v0.2.1", newerThan: "0.2"))
  }

  @Test func decodesGitHubRelease() throws {
    let json = #"{"tag_name":"v0.1.0","html_url":"https://github.com/atleugim/zul/releases/tag/v0.1.0","draft":false}"#
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    let release = try decoder.decode(Release.self, from: Data(json.utf8))

    #expect(
      release
        == Release(tagName: "v0.1.0", htmlUrl: URL(string: "https://github.com/atleugim/zul/releases/tag/v0.1.0")!))
  }
}
