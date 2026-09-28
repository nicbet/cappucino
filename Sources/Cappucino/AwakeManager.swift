import Foundation
import ServiceManagement

@MainActor
final class AwakeManager: ObservableObject {
    /// What happens when no timer is running.
    enum Baseline: String {
        case agents, never
    }

    /// A manual timer overrides the baseline and ignores agents entirely.
    enum ManualTimer: Equatable {
        case indefinite
        case until(Date, preset: TimeInterval)
    }

    static let presets: [(label: String, duration: TimeInterval)] = [
        ("1h", 3600), ("2h", 7200), ("4h", 14400), ("8h", 28800),
    ]
    static let lingerOptions = [0, 5, 10, 15, 30]

    // MARK: State

    @Published private(set) var manualTimer: ManualTimer?
    @Published private(set) var isAwake = false
    @Published private(set) var runningAgents: [String] = []
    @Published private(set) var lingerUntil: Date?
    @Published private(set) var displayBlockers: [DisplayBlocker] = []
    @Published private(set) var power = PowerSettings()
    @Published private(set) var now = Date()

    // MARK: Settings

    @Published var baseline: Baseline {
        didSet { defaults.set(baseline.rawValue, forKey: Keys.baseline); tick() }
    }
    @Published var letDisplaysSleep: Bool {
        didSet { defaults.set(letDisplaysSleep, forKey: Keys.letDisplaysSleep); tick() }
    }
    @Published var lingerMinutes: Int {
        didSet { defaults.set(lingerMinutes, forKey: Keys.lingerMinutes); tick() }
    }
    @Published var agentNames: [String] {
        didSet { defaults.set(agentNames, forKey: Keys.agentNames); tick() }
    }
    @Published private(set) var launchAtLogin = SMAppService.mainApp.status == .enabled

    private enum Keys {
        static let baseline = "baseline"
        static let letDisplaysSleep = "letDisplaysSleep"
        static let lingerMinutes = "lingerMinutes"
        static let agentNames = "agentNames"
    }

    private let defaults = UserDefaults.standard
    private let systemAssertion = PowerAssertion(type: .preventIdleSystemSleep)
    private let displayAssertion = PowerAssertion(type: .preventIdleDisplaySleep)
    private var timer: Timer?
    private var ticks = 0

    init() {
        defaults.register(defaults: [
            Keys.baseline: Baseline.agents.rawValue,
            Keys.letDisplaysSleep: true,
            Keys.lingerMinutes: 5,
            Keys.agentNames: AgentDetector.defaultAgents,
        ])
        baseline = Baseline(rawValue: defaults.string(forKey: Keys.baseline) ?? "") ?? .agents
        letDisplaysSleep = defaults.bool(forKey: Keys.letDisplaysSleep)
        lingerMinutes = defaults.integer(forKey: Keys.lingerMinutes)
        agentNames = defaults.stringArray(forKey: Keys.agentNames) ?? AgentDetector.defaultAgents

        refreshPowerInfo()
        tick()
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
    }

    // MARK: Actions

    /// Selects "while agents run" or "never", cancelling any manual timer.
    func select(_ baseline: Baseline) {
        manualTimer = nil
        self.baseline = baseline
    }

    /// Starts a manual timer; nil keeps the Mac awake until cancelled.
    func startTimer(_ duration: TimeInterval?) {
        if let duration {
            manualTimer = .until(Date().addingTimeInterval(duration), preset: duration)
        } else {
            manualTimer = .indefinite
        }
        tick()
    }

    func sleepDisplays() {
        DisplayPower.sleepNow()
    }

    func refreshPowerInfo() {
        power = DisplayPower.settings()
        displayBlockers = DisplayPower.blockers()
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Cappucino: launch at login failed: \(error.localizedDescription)")
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    // MARK: Evaluation

    private func tick() {
        now = Date()

        if case .until(let end, _) = manualTimer, end <= now {
            manualTimer = nil
        }

        let followAgents = manualTimer == nil && baseline == .agents
        let previouslyRunning = !runningAgents.isEmpty
        runningAgents = followAgents ? AgentDetector.scan(for: Set(agentNames)).keys.sorted() : []

        if !runningAgents.isEmpty || !followAgents {
            lingerUntil = nil
        } else if previouslyRunning && lingerMinutes > 0 {
            lingerUntil = now.addingTimeInterval(TimeInterval(lingerMinutes * 60))
        } else if let until = lingerUntil, until <= now {
            lingerUntil = nil
        }

        if let reason = awakeReason {
            systemAssertion.hold(reason: "Cappucino: \(reason)")
            if letDisplaysSleep {
                displayAssertion.release()
            } else {
                displayAssertion.hold(reason: "Cappucino: displays kept on")
            }
        } else {
            systemAssertion.release()
            displayAssertion.release()
        }
        isAwake = systemAssertion.isHeld

        // Power info shells out to pmset; refresh it less often.
        ticks += 1
        if ticks % 6 == 0 { refreshPowerInfo() }
    }

    /// Why the Mac is being kept awake (ASCII only, powerd drops other names),
    /// or nil if it may sleep.
    private var awakeReason: String? {
        if manualTimer != nil { return "manual timer" }
        if !runningAgents.isEmpty { return "AI agents running (\(runningAgents.joined(separator: ", ")))" }
        if lingerUntil != nil { return "AI agents recently finished" }
        return nil
    }

    // MARK: Presentation

    var headline: String {
        isAwake ? "Keeping your Mac awake" : "Not keeping your Mac awake"
    }

    var detail: String {
        switch manualTimer {
        case .indefinite:
            return "Until you turn it off"
        case .until(let end, _):
            return "Timer, \(Self.format(end.timeIntervalSince(now))) left"
        case nil:
            break
        }
        if !runningAgents.isEmpty {
            return "\(Self.list(runningAgents)) \(runningAgents.count == 1 ? "is" : "are") running"
        }
        if let until = lingerUntil {
            return "Agents finished, allowing sleep in \(Self.format(until.timeIntervalSince(now)))"
        }
        switch power.systemSleep {
        case .none: return "Your Mac can sleep normally"
        case .some(0): return "Idle sleep is off in System Settings"
        case .some(let minutes): return "Your Mac sleeps after \(minutes) min idle"
        }
    }

    /// Short countdown for the menu bar while a timer is running.
    var menuBarCountdown: String? {
        guard case .until(let end, _) = manualTimer else { return nil }
        let remaining = max(0, Int(end.timeIntervalSince(now)))
        let hours = remaining / 3600
        let minutes = (remaining % 3600) / 60
        // Constant-width h:mm so the status item doesn't resize as it counts down.
        return String(format: "%d:%02d", hours, minutes)
    }

    static func format(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval.rounded()))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        if minutes > 0 { return "\(minutes)m" }
        return "<1m"
    }

    static func list(_ items: [String]) -> String {
        guard items.count > 1 else { return items.first ?? "" }
        return items.dropLast().joined(separator: ", ") + " and " + items.last!
    }
}
