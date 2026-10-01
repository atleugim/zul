import SwiftUI

@Observable
final class AppDelegate: NSObject, NSApplicationDelegate {
  let nowPlaying = NowPlayingService()
  let lyrics = LyricsController()
  @ObservationIgnored private var panel: OverlayPanel?

  // Not persisted: the overlay should always launch click-through.
  var isMovingOverlay = false {
    didSet { panel?.isMoving = isMovingOverlay }
  }

  func applicationDidFinishLaunching(_ notification: Notification) {
    nowPlaying.start()
    let panel = OverlayPanel(content: OverlayView(nowPlaying: nowPlaying, lyrics: lyrics))
    panel.orderFrontRegardless()
    self.panel = panel
  }
}

@main
struct ZulApp: App {
  @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

  var body: some Scene {
    MenuBarExtra("Zul", systemImage: "music.note") {
      MenuContent(
        nowPlaying: appDelegate.nowPlaying,
        lyrics: appDelegate.lyrics,
        isMovingOverlay: Binding(get: { appDelegate.isMovingOverlay }, set: { appDelegate.isMovingOverlay = $0 })
      )
    }
    Settings {
      SettingsView()
    }
  }
}
