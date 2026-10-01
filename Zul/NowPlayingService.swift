import Foundation
import Observation

struct NowPlayingPayload: Decodable {
  let bundleIdentifier: String?
  let parentApplicationBundleIdentifier: String?
  let title: String?
  let artist: String?
  let album: String?
  let durationMicros: Double?
  let elapsedTimeMicros: Double?
  let timestampEpochMicros: Double?
  let playbackRate: Double?
  let playing: Bool?
}

struct StreamMessage: Decodable {
  // Empty object when nothing is playing, which decodes to all-nil fields.
  let payload: NowPlayingPayload
}

@Observable
final class NowPlayingService {
  private(set) var nowPlaying: NowPlaying?
  // Never written to: the kernel closes it when the app dies for any reason,
  // and the EOF tells the wrapper to kill perl so it isn't left orphaned.
  @ObservationIgnored private var lifeline: Pipe?

  func start() {
    Task {
      while true {
        try? await streamAdapter()
        // The adapter exited (crashed, or a macOS update broke MediaRemote access), so the
        // last state it reported is stale; clearing it hides lyrics that would keep advancing.
        nowPlaying = nil
        try? await Task.sleep(for: .seconds(5))
      }
    }
  }

  private func streamAdapter() async throws {
    let script = Bundle.main.url(forResource: "mediaremote-adapter", withExtension: "pl")!
    let framework = Bundle.main.privateFrameworksURL!.appending(path: "MediaRemoteAdapter.framework")
    let process = Process()
    let lifeline = Pipe()
    let output = Pipe()
    process.executableURL = URL(filePath: "/bin/sh")
    // Background jobs get /dev/null as stdin, so the lifeline is kept on fd 3 for the watcher.
    // The watcher's stdout goes to /dev/null so that, once perl exits, the output pipe closes.
    process.arguments = [
      "-c",
      #"exec 3<&0; /usr/bin/perl "$0" "$1" stream --no-diff --no-artwork --micros & pid=$!; (read _ <&3; kill $pid) >/dev/null 2>&1 & wait $pid"#,
      script.path, framework.path,
    ]
    process.standardInput = lifeline
    process.standardOutput = output
    try process.run()
    // Replacing the previous lifeline closes it, which also ends that run's leftover watcher.
    self.lifeline = lifeline

    let decoder = JSONDecoder()
    for try await line in output.fileHandleForReading.bytes.lines {
      guard let message = try? decoder.decode(StreamMessage.self, from: Data(line.utf8)) else { continue }
      nowPlaying = NowPlaying(payload: message.payload)
    }
  }
}
