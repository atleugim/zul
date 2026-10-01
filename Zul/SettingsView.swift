import ServiceManagement
import SwiftUI

private struct Swatch {
  let name: String
  let hex: String
}

// Neutral, light tones: the overlay is for reading, and they stay legible over the dark text shadow.
private let swatches = [
  Swatch(name: "White", hex: "#FFFFFF"),
  Swatch(name: "Ivory", hex: "#F5F0E1"),
  Swatch(name: "Light Gray", hex: "#D1D1D6"),
  Swatch(name: "Gray", hex: "#A1A1A6"),
  Swatch(name: "Soft Blue", hex: "#CFE0F2"),
  Swatch(name: "Soft Amber", hex: "#F2DDB0"),
]

struct SettingsView: View {
  @AppStorage(Preferences.overlayPosition.key) private var position = Preferences.overlayPosition.defaultValue
  @AppStorage(Preferences.fontFamily.key) private var fontFamily = Preferences.fontFamily.defaultValue
  @AppStorage(Preferences.fontColor.key) private var fontColor = Preferences.fontColor.defaultValue
  @AppStorage(Preferences.fontSize.key) private var fontSize = Preferences.fontSize.defaultValue
  @AppStorage(Preferences.overlayOpacity.key) private var opacity = Preferences.overlayOpacity.defaultValue
  @AppStorage(Preferences.showOnAllSpaces.key) private var showOnAllSpaces = Preferences.showOnAllSpaces.defaultValue
  @AppStorage(Preferences.globalOffset.key) private var globalOffset = Preferences.globalOffset.defaultValue
  private let fontFamilies = NSFontManager.shared.availableFontFamilies
  // Read from the system rather than stored: it can also be turned off in System Settings.
  @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
  @State private var updateStatus = UpdateStatus.idle

  private enum UpdateStatus: Equatable {
    case idle
    case checking
    case upToDate
    case available(version: String, page: URL)
    case failed
  }

  var body: some View {
    Form {
      Section("General") {
        Toggle("Launch at Login", isOn: $launchAtLogin)
          .onChange(of: launchAtLogin) { _, enabled in
            try? enabled ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister()
            // Reflects what actually happened if registration failed or needs approval.
            launchAtLogin = SMAppService.mainApp.status == .enabled
          }
        LabeledContent {
          Button("Check for Updates") {
            Task { await checkForUpdates() }
          }
          .disabled(updateStatus == .checking)
        } label: {
          Text("Updates")
          if let message = updateMessage {
            Text(message)
          }
        }
        if case .available(_, let page) = updateStatus {
          Link("Download from GitHub", destination: page)
        }
      }
      Section("Timing") {
        Stepper(value: $globalOffset, in: -5...5, step: 0.1) {
          Text(
            "Output Latency Offset: \(globalOffset.formatted(.number.precision(.fractionLength(1)).sign(strategy: .always()))) s"
          )
          Text("Applies to every song. Use a negative value when audio reaches you late, e.g. −2 s for AirPlay.")
        }
      }
      Section("Font") {
        Picker("Family", selection: $fontFamily) {
          Text("System").tag("")
          Divider()
          ForEach(fontFamilies, id: \.self) { family in
            Text(family).tag(family)
          }
        }
        LabeledContent("Color") {
          HStack(spacing: 8) {
            ForEach(swatches, id: \.hex) { swatch in
              Button {
                fontColor = swatch.hex
              } label: {
                Circle()
                  .fill(Color(hex: swatch.hex) ?? .white)
                  .overlay(Circle().strokeBorder(.secondary.opacity(0.5), lineWidth: 0.5))
                  .frame(width: 18, height: 18)
                  .padding(3)
                  .overlay {
                    if fontColor == swatch.hex {
                      Circle().strokeBorder(Color.accentColor, lineWidth: 2)
                    }
                  }
              }
              .buttonStyle(.plain)
              .accessibilityLabel(swatch.name)
            }
            ColorPicker(
              "Custom Color",
              selection: Binding(get: { Color(hex: fontColor) ?? .white }, set: { fontColor = $0.hex }),
              // Opacity has its own setting.
              supportsOpacity: false
            )
            .labelsHidden()
          }
        }
        Slider(value: $fontSize, in: 18...48, step: 2) {
          Text("Size")
        }
      }
      Section {
        Picker("Position", selection: $position) {
          Text("Top").tag(OverlayPosition.top)
          Text("Bottom").tag(OverlayPosition.bottom)
          Text("Custom").tag(OverlayPosition.custom)
        }
        Slider(value: $opacity, in: 0.3...1) {
          Text("Opacity")
        }
        Toggle(isOn: $showOnAllSpaces) {
          Text("Show on All Desktops")
          Text("When off, the overlay stays on the desktop you're on when you turn this off.")
        }
      } header: {
        Text("Overlay")
      } footer: {
        // In the last section's footer so it sits at the end of the scroll, not pinned.
        Link(destination: Repository.url) {
          Text("Zul \(Bundle.main.shortVersion)")
            .underline()
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
      }
    }
    .formStyle(.grouped)
    .frame(width: 380)
  }

  private var updateMessage: String? {
    switch updateStatus {
    case .idle: nil
    case .checking: "Checking…"
    case .upToDate: "You're on the latest version."
    case .available(let version, _): "Zul \(version) is available."
    case .failed: "Couldn't check for updates."
    }
  }

  private func checkForUpdates() async {
    updateStatus = .checking
    do {
      let release = try await UpdateChecker.latestRelease()
      let isNewer = UpdateChecker.isVersion(release.tagName, newerThan: Bundle.main.shortVersion)
      let version = String(release.tagName.trimmingPrefix("v"))
      updateStatus = isNewer ? .available(version: version, page: release.htmlUrl) : .upToDate
    } catch {
      updateStatus = .failed
    }
  }
}
