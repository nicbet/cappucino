import SwiftUI
import AppKit

@main
struct CappucinoApp: App {
    @StateObject private var manager = AwakeManager()

    var body: some Scene {
        MenuBarExtra {
            PopoverView()
                .environmentObject(manager)
        } label: {
            // Outline and filled variants of the same glyph share a width, so the
            // status item (and the popover anchored to it) never shifts.
            HStack(spacing: 3) {
                Image(systemName: manager.isAwake ? "cup.and.saucer.fill" : "cup.and.saucer")
                if let countdown = manager.menuBarCountdown {
                    Text(countdown)
                        .monospacedDigit()
                }
            }
        }
        .menuBarExtraStyle(.window)

        Window("Settings", id: "settings") {
            SettingsView()
                .environmentObject(manager)
        }
        .windowResizability(.contentSize)
    }
}

