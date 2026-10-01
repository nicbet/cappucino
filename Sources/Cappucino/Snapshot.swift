import AppKit
import SwiftUI

/// Renders the popover and Settings to PNGs for the README, in light and dark, without Screen
/// Recording permission (`Cappucino --snapshot <dir>`, or `make snapshot`).
@MainActor
enum Snapshot {
    private static let scale: CGFloat = 2

    static func run(to path: String) -> Never {
        let delegate = Launcher(directory: URL(fileURLWithPath: path))
        NSApplication.shared.setActivationPolicy(.accessory)
        NSApp.delegate = delegate
        NSApp.run()
        exit(0)
    }

    /// Controls draw dimmed unless the app is active, which needs a running app.
    private final class Launcher: NSObject, NSApplicationDelegate {
        let directory: URL
        init(directory: URL) { self.directory = directory }

        func applicationDidFinishLaunching(_ notification: Notification) {
            NSApp.activate(ignoringOtherApps: true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [directory] in
                do {
                    for url in try Snapshot.write(to: directory) { print(url.path) }
                    exit(0)
                } catch {
                    FileHandle.standardError.write(Data("snapshot failed: \(error)\n".utf8))
                    exit(1)
                }
            }
        }
    }

    static func write(to directory: URL) throws -> [URL] {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let now = Date()
        let popovers: [(String, AwakeManager.SnapshotState)] = [
            ("agents", .init(runningAgents: ["claude", "codex"])),
            ("timer", .init(manualTimer: .until(now.addingTimeInterval(3 * 3600 + 12 * 60 + 30), preset: 14400))),
            ("lingering", .init(lingerUntil: now.addingTimeInterval(4 * 60 + 30))),
            ("idle", .init()),
            ("burn-in", .init(runningAgents: ["claude"],
                              displayBlockers: [DisplayBlocker(pid: 1, name: "Google Chrome", reason: "Video Wake Lock")],
                              power: PowerSettings(systemSleep: 10, displaySleep: 0))),
        ]

        var urls: [URL] = []
        for dark in [false, true] {
            let suffix = dark ? "dark" : "light"
            for (name, state) in popovers {
                let manager = AwakeManager(snapshot: state)
                let popover = capture(PopoverView().environmentObject(manager), dark: dark)
                let scene = MenuBarScene(popover: popover, isAwake: manager.isAwake,
                                         countdown: manager.menuBarCountdown, dark: dark)
                urls.append(try save(scene, to: directory.appendingPathComponent("popover-\(name)-\(suffix).png")))
            }

            let manager = AwakeManager(snapshot: .init(runningAgents: ["claude", "codex"]))
            let settings = capture(SettingsView().environmentObject(manager), dark: dark, title: "Settings")
            let scene = WindowScene(window: settings, dark: dark)
            urls.append(try save(scene, to: directory.appendingPathComponent("settings-\(suffix).png")))
        }
        return urls
    }

    /// Draws `view` in an offscreen window. With a title, the window's frame (title bar and
    /// traffic lights) is drawn too; without one, only the view.
    private static func capture<V: View>(_ view: V, dark: Bool, title: String? = nil) -> NSImage {
        let appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        let host = NSHostingView(rootView: view)
        let size = host.fittingSize
        let window = KeyWindow(contentRect: CGRect(origin: .zero, size: size),
                              styleMask: title == nil ? [.borderless] : [.titled, .closable, .miniaturizable],
                              backing: .buffered, defer: false)
        window.appearance = appearance
        window.title = title ?? ""
        window.contentView = host
        // On screen (for key status), but far outside the visible area.
        window.setFrameOrigin(NSPoint(x: -20000, y: -20000))
        window.orderFrontRegardless()
        window.makeKey()
        window.layoutIfNeeded()
        // Let SwiftUI finish its first update passes.
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))

        let target = title == nil ? host : (host.superview ?? host)
        let bounds = target.bounds
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                         pixelsWide: Int(bounds.width * scale), pixelsHigh: Int(bounds.height * scale),
                                         bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                         colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
        else { return NSImage() }
        rep.size = bounds.size
        appearance?.performAsCurrentDrawingAppearance {
            if title == nil, let context = NSGraphicsContext(bitmapImageRep: rep) {
                // A borderless window doesn't draw its background into the cache.
                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.current = context
                NSColor.windowBackgroundColor.setFill()
                bounds.fill()
                NSGraphicsContext.restoreGraphicsState()
            }
            target.cacheDisplay(in: bounds, to: rep)
        }
        window.orderOut(nil)
        let image = NSImage(size: bounds.size)
        image.addRepresentation(rep)
        return image
    }

    private static func save<V: View>(_ view: V, to url: URL) throws -> URL {
        let renderer = ImageRenderer(content: view)
        renderer.scale = scale
        guard let image = renderer.cgImage,
              let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
        else { throw CocoaError(.fileWriteUnknown) }
        try data.write(to: url)
        return url
    }
}

/// Becomes key even when borderless, so its controls draw active.
private final class KeyWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// A coffee-colored desktop.
private struct Wallpaper: View {
    let dark: Bool

    var body: some View {
        ZStack {
            LinearGradient(colors: dark
                               ? [Color(red: 0.16, green: 0.09, blue: 0.06), Color(red: 0.36, green: 0.21, blue: 0.13)]
                               : [Color(red: 0.96, green: 0.87, blue: 0.75), Color(red: 0.80, green: 0.58, blue: 0.40)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            RadialGradient(colors: [Color.crema.opacity(dark ? 0.35 : 0.5), .clear],
                           center: UnitPoint(x: 0.2, y: 0.85), startRadius: 0, endRadius: 420)
        }
    }
}

/// The popover hanging from its menu bar item.
private struct MenuBarScene: View {
    let popover: NSImage
    let isAwake: Bool
    let countdown: String?
    let dark: Bool

    private let width: CGFloat = 760
    private let barHeight: CGFloat = 26
    private var ink: Color { dark ? .white : .black }

    var body: some View {
        ZStack(alignment: .top) {
            Wallpaper(dark: dark)

            HStack(spacing: 18) {
                Image(systemName: "apple.logo").font(.system(size: 14))
                Text("Terminal").fontWeight(.bold)
                ForEach(["Shell", "Edit", "View", "Window", "Help"], id: \.self) { Text($0) }
                Spacer()
                Image(systemName: "wifi")
                Image(systemName: "battery.75percent")
                Image(systemName: "switch.2")
                Text("Thu 1 Oct  9:41")
            }
            .font(.system(size: 13))
            .foregroundStyle(ink)
            .padding(.horizontal, 16)
            .frame(height: barHeight)
            .background((dark ? Color.black : Color.white).opacity(dark ? 0.3 : 0.35))

            // The popover's column lines up its item with the popover's center.
            VStack(spacing: 5) {
                statusItem
                Image(nsImage: popover)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.primary.opacity(dark ? 0.2 : 0.12), lineWidth: 0.5))
                    .shadow(color: .black.opacity(dark ? 0.5 : 0.25), radius: 24, y: 12)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.trailing, 150)
        }
        .frame(width: width, height: barHeight + 5 + popover.size.height + 56)
        .environment(\.colorScheme, dark ? .dark : .light)
    }

    private var statusItem: some View {
        HStack(spacing: 3) {
            Image(nsImage: isAwake ? MenuBarIcon.awake : MenuBarIcon.idle)
                .renderingMode(.template)
            if let countdown {
                Text(countdown).monospacedDigit()
            }
        }
        .font(.system(size: 13))
        .foregroundStyle(ink)
        .padding(.horizontal, 7)
        .frame(height: barHeight - 4)
        .background(RoundedRectangle(cornerRadius: 5).fill(ink.opacity(0.18)))
        .frame(height: barHeight)
    }
}

/// A window on the desktop.
private struct WindowScene: View {
    let window: NSImage
    let dark: Bool

    var body: some View {
        ZStack {
            Wallpaper(dark: dark)
            Image(nsImage: window)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.primary.opacity(dark ? 0.2 : 0.12), lineWidth: 0.5))
                .shadow(color: .black.opacity(dark ? 0.5 : 0.25), radius: 24, y: 12)
        }
        .frame(width: window.size.width + 160, height: window.size.height + 120)
        .environment(\.colorScheme, dark ? .dark : .light)
    }
}
