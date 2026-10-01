import AppKit
import SwiftUI

enum OverlayPosition: String {
  case top
  case bottom
  // Wherever the panel was last dragged in move mode.
  case custom
}

final class OverlayPanel: NSPanel {
  private var appliedPosition: OverlayPosition?
  private var appliedAllSpaces: Bool?

  // Makes the panel draggable and shows its bounds, since it may have no lyrics to grab.
  var isMoving = false {
    didSet {
      ignoresMouseEvents = !isMoving
      backgroundColor = isMoving ? NSColor.black.withAlphaComponent(0.35) : .clear
    }
  }

  init(content: some View) {
    super.init(
      // Tall enough for the largest font size setting.
      contentRect: NSRect(x: 0, y: 0, width: 800, height: 160),
      // Non-activating so showing lyrics never steals focus from the app in use.
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )
    isOpaque = false
    backgroundColor = .clear
    hasShadow = false
    // Panels default to hiding when their app deactivates, and this app is almost never active.
    hidesOnDeactivate = false
    level = .floating
    ignoresMouseEvents = true
    contentView = NSHostingView(rootView: content)

    applyPosition()
    applySpaces()
    NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) {
      [weak self] _ in
      MainActor.assumeIsolated {
        self?.applyPosition()
        self?.applySpaces()
      }
    }
    NotificationCenter.default.addObserver(forName: NSWindow.didMoveNotification, object: self, queue: .main) {
      [weak self] _ in
      MainActor.assumeIsolated { self?.saveCustomPosition() }
    }
    // Any display change (connecting, disconnecting, resolution, arrangement) can leave the
    // panel off-screen or off-center.
    NotificationCenter.default.addObserver(
      forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
    ) { [weak self] _ in
      MainActor.assumeIsolated {
        self?.appliedPosition = nil
        self?.applyPosition()
      }
    }
  }

  // The SwiftUI content would swallow the mouse-down, so the drag starts here instead.
  override func sendEvent(_ event: NSEvent) {
    if isMoving, event.type == .leftMouseDown {
      performDrag(with: event)
    } else {
      super.sendEvent(event)
    }
  }

  private func saveCustomPosition() {
    guard isMoving else { return }
    // Set first so the defaults change below doesn't snap the panel back.
    appliedPosition = .custom
    UserDefaults.standard.set(NSStringFromPoint(frame.origin), forKey: Preferences.overlayOrigin.key)
    UserDefaults.standard.set(OverlayPosition.custom.rawValue, forKey: Preferences.overlayPosition.key)
  }

  // Without canJoinAllSpaces the panel stays on the desktop that was active when it was set.
  private func applySpaces() {
    let allSpaces =
      UserDefaults.standard.object(forKey: Preferences.showOnAllSpaces.key) as? Bool
      ?? Preferences.showOnAllSpaces.defaultValue
    // Like applyPosition: reassigning on unrelated defaults changes could re-pin it to another desktop.
    guard allSpaces != appliedAllSpaces else { return }
    appliedAllSpaces = allSpaces
    collectionBehavior = allSpaces ? [.canJoinAllSpaces, .fullScreenAuxiliary] : [.fullScreenAuxiliary]
  }

  private func applyPosition() {
    let position =
      UserDefaults.standard.string(forKey: Preferences.overlayPosition.key).flatMap(OverlayPosition.init)
      ?? Preferences.overlayPosition.defaultValue
    // Every defaults change lands here; only an actual position change should move the panel.
    guard position != appliedPosition, let screen = NSScreen.main?.visibleFrame else { return }
    appliedPosition = position
    let centerX = screen.midX - frame.width / 2
    let bottom = NSPoint(x: centerX, y: screen.minY + 80)
    switch position {
    case .top:
      setFrameOrigin(NSPoint(x: centerX, y: screen.maxY - frame.height - 40))
    case .bottom:
      setFrameOrigin(bottom)
    case .custom:
      let saved = UserDefaults.standard.string(forKey: Preferences.overlayOrigin.key).map(NSPointFromString)
      // Falls back to the bottom preset when nothing was dragged yet, or when the saved spot
      // is on a display that's no longer connected and the panel would be unreachable.
      if let saved, isOnAnyScreen(NSRect(origin: saved, size: frame.size)) {
        setFrameOrigin(saved)
      } else {
        setFrameOrigin(bottom)
      }
    }
  }

  private func isOnAnyScreen(_ rect: NSRect) -> Bool {
    NSScreen.screens.contains { $0.visibleFrame.intersects(rect) }
  }
}
