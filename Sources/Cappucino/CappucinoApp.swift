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
            Image(nsImage: MenuBarIcon.render(awake: manager.isAwake, countdown: manager.menuBarCountdown))
        }
        .menuBarExtraStyle(.window)

        Window("Settings", id: "settings") {
            SettingsView()
                .environmentObject(manager)
        }
        .windowResizability(.contentSize)
    }
}

/// Draws the menu bar label into a fixed-width template image. The two cup
/// symbols have different natural widths, and a resizing status item makes
/// the menu bar and the attached popover jump around.
enum MenuBarIcon {
    private static let height: CGFloat = 18
    private static let awakeSymbol = symbol("cup.and.heat.waves.fill")
    private static let idleSymbol = symbol("cup.and.saucer")
    private static let symbolWidth = ceil(max(awakeSymbol.size.width, idleSymbol.size.width))
    private static let font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)

    static func render(awake: Bool, countdown: String?) -> NSImage {
        let symbol = awake ? awakeSymbol : idleSymbol
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.black]
        let textSize = countdown.map { ($0 as NSString).size(withAttributes: attrs) } ?? .zero
        let spacing: CGFloat = countdown == nil ? 0 : 4
        let size = NSSize(width: symbolWidth + spacing + ceil(textSize.width), height: height)

        let image = NSImage(size: size, flipped: false) { _ in
            let s = symbol.size
            symbol.draw(in: NSRect(
                x: (symbolWidth - s.width) / 2,
                y: (height - s.height) / 2,
                width: s.width,
                height: s.height
            ))
            if let countdown {
                (countdown as NSString).draw(
                    at: NSPoint(x: symbolWidth + spacing, y: (height - textSize.height) / 2),
                    withAttributes: attrs
                )
            }
            return true
        }
        image.isTemplate = true
        return image
    }

    private static func symbol(_ name: String) -> NSImage {
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        return NSImage(systemSymbolName: name, accessibilityDescription: "Cappucino")?
            .withSymbolConfiguration(config) ?? NSImage()
    }
}
