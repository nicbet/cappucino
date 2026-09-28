import AppKit

/// Menu bar cups from Phosphor Icons (MIT, see THIRD_PARTY_NOTICES.md).
/// Both are cropped to the same box (the steaming cup's bounds), so switching
/// between them never resizes the status item or shifts the popover anchored
/// to it, and the glyph is 16pt tall like other menu bar icons.
enum MenuBarIcon {
    static let awake = image(steam + filledCup)
    static let idle = image(outlineCup)

    // Glyph bounds within Phosphor's 256×256 grid: x 24–248, y 16–224.
    private static let viewBox = (x: 24.0, y: 16.0, width: 224.0, height: 208.0)
    private static let height: CGFloat = 16
    private static let size = NSSize(width: height * viewBox.width / viewBox.height, height: height)

    // "coffee" steam strokes.
    private static let steam = "M80,56V24a8,8,0,0,1,16,0V56a8,8,0,0,1-16,0Zm40,8a8,8,0,0,0,8-8V24a8,8,0,0,0-16,0V56A8,8,0,0,0,120,64Zm32,0a8,8,0,0,0,8-8V24a8,8,0,0,0-16,0V56A8,8,0,0,0,152,64Z"
    // "coffee-fill" cup without its steam.
    private static let filledCup = "M208,80H32a8,8,0,0,0-8,8v48a96.3,96.3,0,0,0,32.54,72H32a8,8,0,0,0,0,16H208a8,8,0,0,0,0-16H183.46a96.59,96.59,0,0,0,27-40.09A40,40,0,0,0,248,128v-8A40,40,0,0,0,208,80Zm24,48a24,24,0,0,1-17.2,23,95.78,95.78,0,0,0,1.2-15V97.38A24,24,0,0,1,232,120Z"
    // "coffee" cup without its steam.
    private static let outlineCup = "M248,120v8a40,40,0,0,1-37.51,39.91,96.59,96.59,0,0,1-27,40.09H208a8,8,0,0,1,0,16H32a8,8,0,0,1,0-16H56.54A96.3,96.3,0,0,1,24,136V88a8,8,0,0,1,8-8H208A40,40,0,0,1,248,120ZM200,96H40v40a80.27,80.27,0,0,0,45.12,72h69.76A80.27,80.27,0,0,0,200,136Zm32,24a24,24,0,0,0-16-22.62V136a95.78,95.78,0,0,1-1.2,15A24,24,0,0,0,232,128Z"

    private static func image(_ pathData: String) -> NSImage {
        let svg = #"<svg xmlns="http://www.w3.org/2000/svg" viewBox="\#(viewBox.x) \#(viewBox.y) \#(viewBox.width) \#(viewBox.height)" fill="black"><path d="\#(pathData)"/></svg>"#
        let image = NSImage(data: Data(svg.utf8)) ?? NSImage()
        image.size = size
        image.isTemplate = true
        image.accessibilityDescription = "Cappucino"
        return image
    }
}
