import Foundation
import IOKit.pwr_mgt

/// Wraps an IOKit power assertion. System and display sleep are separate:
/// holding only `.preventIdleSystemSleep` keeps the Mac running while the
/// displays still sleep (equivalent to `caffeinate -i`). The kernel releases
/// assertions automatically if the process exits.
final class PowerAssertion {
    // CFSTR() macros from IOPMLib.h are not imported into Swift.
    enum Kind: String {
        case preventIdleSystemSleep = "PreventUserIdleSystemSleep"
        case preventIdleDisplaySleep = "PreventUserIdleDisplaySleep"
    }

    private let type: Kind

    private var assertionID: IOPMAssertionID = 0
    private var reason = ""
    private(set) var isHeld = false

    init(type: Kind) {
        self.type = type
    }

    /// Takes the assertion, or re-creates it if the reason changed so that
    /// `pmset -g assertions` always shows why the Mac is being kept awake.
    func hold(reason: String) {
        if isHeld && reason == self.reason { return }
        release()

        var newID: IOPMAssertionID = 0
        let result = IOPMAssertionCreateWithName(
            type.rawValue as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason as CFString,
            &newID
        )
        guard result == kIOReturnSuccess else { return }
        assertionID = newID
        self.reason = reason
        isHeld = true
    }

    func release() {
        guard isHeld else { return }
        IOPMAssertionRelease(assertionID)
        assertionID = 0
        reason = ""
        isHeld = false
    }

    deinit { release() }
}
