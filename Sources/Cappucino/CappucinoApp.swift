import SwiftUI
import AppKit

struct CappucinoApp: App {
    @StateObject private var manager = AwakeManager()

    var body: some Scene {
        MenuBarExtra {
            PopoverView()
                .environmentObject(manager)
        } label: {
            HStack(spacing: 3) {
                Image(nsImage: manager.isAwake ? MenuBarIcon.awake : MenuBarIcon.idle)
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

