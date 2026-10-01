import Foundation

@main
@MainActor
enum Entry {
    static func main() {
        // Dev tool: `Cappucino --snapshot <dir>` renders the UI to PNGs and exits.
        if let flag = CommandLine.arguments.firstIndex(of: "--snapshot") {
            Snapshot.run(to: CommandLine.arguments.dropFirst(flag + 1).first ?? ".build/snapshots")
        }
        CappucinoApp.main()
    }
}
