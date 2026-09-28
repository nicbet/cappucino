import AppKit
import IOKit.pwr_mgt

/// An app currently holding an assertion that stops the displays from sleeping.
struct DisplayBlocker: Identifiable, Hashable {
    let pid: pid_t
    let name: String
    let reason: String
    var id: pid_t { pid }
}

/// Idle timeouts for the current power source, in minutes (0 means never).
struct PowerSettings: Equatable {
    var systemSleep: Int?
    var displaySleep: Int?
}

enum DisplayPower {
    private static let displayAssertionTypes: Set<String> = [
        "PreventUserIdleDisplaySleep",
        "NoDisplaySleepAssertion",
    ]

    /// Turns the displays off immediately. Does not require root.
    static func sleepNow() {
        run(["displaysleepnow"])
    }

    /// The `sleep` and `displaysleep` settings currently in use.
    static func settings() -> PowerSettings {
        var settings = PowerSettings()
        guard let output = run(["-g"]) else { return settings }
        for line in output.split(separator: "\n") {
            let fields = line.split(separator: " ", omittingEmptySubsequences: true)
            guard fields.count >= 2 else { continue }
            switch fields[0] {
            case "sleep": settings.systemSleep = Int(fields[1])
            case "displaysleep": settings.displaySleep = Int(fields[1])
            default: break
            }
        }
        return settings
    }

    /// Other processes that are preventing display sleep (video players,
    /// presentation apps, other keep-awake tools...).
    static func blockers() -> [DisplayBlocker] {
        var unmanaged: Unmanaged<CFDictionary>?
        guard IOPMCopyAssertionsByProcess(&unmanaged) == kIOReturnSuccess,
              let byPID = unmanaged?.takeRetainedValue() as? [NSNumber: [[String: Any]]]
        else { return [] }

        let ownPID = getpid()
        var result: [DisplayBlocker] = []
        for (pidNumber, assertions) in byPID {
            let pid = pidNumber.int32Value
            guard pid != ownPID,
                  let assertion = assertions.first(where: {
                      displayAssertionTypes.contains($0["AssertType"] as? String ?? "")
                  })
            else { continue }

            let name = NSRunningApplication(processIdentifier: pid)?.localizedName
                ?? processName(pid)
            result.append(DisplayBlocker(
                pid: pid,
                name: name,
                reason: assertion["AssertName"] as? String ?? ""
            ))
        }
        return result.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private static func processName(_ pid: pid_t) -> String {
        var buffer = [CChar](repeating: 0, count: 256)
        guard proc_name(pid, &buffer, UInt32(buffer.count)) > 0 else { return "PID \(pid)" }
        return String(cString: buffer)
    }

    @discardableResult
    private static func run(_ arguments: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return nil
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(data: data, encoding: .utf8)
    }
}
