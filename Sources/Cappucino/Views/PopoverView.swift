import SwiftUI

extension Color {
    // Espresso #8B5A3C, crema #C8A27A
    static let espresso = Color(red: 0x8B / 255.0, green: 0x5A / 255.0, blue: 0x3C / 255.0)
    static let crema = Color(red: 0xC8 / 255.0, green: 0xA2 / 255.0, blue: 0x7A / 255.0)
}

struct PopoverView: View {
    @EnvironmentObject var manager: AwakeManager
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 0) {
            StatusCard(isAwake: manager.isAwake, headline: manager.headline, detail: manager.detail)
                .padding(12)
            Divider().padding(.horizontal)
            modeSection
            Divider().padding(.horizontal)
            displaySection
            Divider().padding(.horizontal)
            footer
        }
        .frame(width: 320)
        .background(.regularMaterial)
        .onAppear { manager.refreshPowerInfo() }
    }

    // MARK: Stay awake

    private var modeSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionLabel("Stay Awake")
                .padding(.bottom, 4)

            ModeRow(
                title: "While agents run",
                subtitle: manager.lingerMinutes > 0
                    ? "Plus \(manager.lingerMinutes) min after the last one finishes"
                    : "Sleep is allowed as soon as they finish",
                selected: manager.manualTimer == nil && manager.baseline == .agents
            ) {
                manager.select(.agents)
            }

            ModeRow(
                title: "For a set time",
                subtitle: "Ignores agents until the time is up",
                selected: manager.manualTimer != nil
            ) {
                if manager.manualTimer == nil { manager.startTimer(3600) }
            }
            HStack(spacing: 6) {
                ForEach(AwakeManager.presets, id: \.duration) { preset in
                    ChoiceButton(label: preset.label, selected: isPresetActive(preset.duration)) {
                        manager.startTimer(preset.duration)
                    }
                }
                ChoiceButton(label: "∞", selected: manager.manualTimer == .indefinite) {
                    manager.startTimer(nil)
                }
                .help("Until you turn it off")
            }
            .padding(.leading, 26)
            .padding(.bottom, 4)

            ModeRow(
                title: "Off",
                subtitle: "Your Mac sleeps on its usual schedule",
                selected: manager.manualTimer == nil && manager.baseline == .never
            ) {
                manager.select(.never)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func isPresetActive(_ duration: TimeInterval) -> Bool {
        if case .until(_, let preset) = manager.manualTimer { return preset == duration }
        return false
    }

    // MARK: Displays

    private var displaySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: $manager.letDisplaysSleep) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Let displays sleep")
                        .font(.system(.body, design: .rounded))
                    Text(displaySubtitle.text)
                        .font(.system(.caption))
                        .foregroundStyle(displaySubtitle.warning ? AnyShapeStyle(.orange) : AnyShapeStyle(.secondary))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .toggleStyle(.switch)
            .controlSize(.small)
            .tint(.espresso)

            Button {
                manager.sleepDisplays()
            } label: {
                Label("Sleep Displays Now", systemImage: "display")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .help("Turn the displays off now. Your Mac and agents keep running.")

            ForEach(manager.displayBlockers) { blocker in
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.orange)
                        .padding(.top, 2)
                    Text("\(blocker.name) is keeping the displays on")
                        .font(.system(.caption))
                        .foregroundStyle(.secondary)
                        .help(blocker.reason)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var displaySubtitle: (text: String, warning: Bool) {
        guard manager.letDisplaysSleep else {
            return ("Kept on while your Mac is kept awake", true)
        }
        switch manager.power.displaySleep {
        case .none: return ("On their normal schedule", false)
        case .some(0): return ("Never, per System Settings (burn-in risk)", true)
        case .some(let minutes): return ("Automatically after \(minutes) min idle", false)
        }
    }

    // MARK: Footer

    private var footer: some View {
        HStack {
            FooterButton(label: "Settings", icon: "gear") {
                NSApp.activate()
                openWindow(id: "settings")
            }
            Spacer()
            FooterButton(label: "Quit", icon: "xmark.circle") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

private struct StatusCard: View {
    let isAwake: Bool
    let headline: String
    let detail: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(isAwake ? Color.espresso : Color.primary.opacity(0.08))
                Image(systemName: isAwake ? "cup.and.heat.waves.fill" : "moon.zzz.fill")
                    .font(.system(size: 17))
                    .foregroundStyle(isAwake ? Color.white : .secondary)
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(headline)
                    .font(.system(.headline, design: .rounded))
                Text(detail)
                    .font(.system(.callout, design: .rounded))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isAwake ? Color.crema.opacity(0.18) : Color.primary.opacity(0.04))
        )
    }
}

private struct ModeRow: View {
    let title: String
    let subtitle: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 14))
                    .foregroundStyle(selected ? Color.espresso : .secondary)
                    .padding(.top, 1)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(.body, design: .rounded))
                        .fontWeight(selected ? .semibold : .regular)
                    Text(subtitle)
                        .font(.system(.caption))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct SectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text.uppercased())
            .font(.system(.caption2, design: .rounded))
            .fontWeight(.semibold)
            .foregroundStyle(.tertiary)
    }
}

private struct ChoiceButton: View {
    let label: String
    let selected: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(.callout, design: .rounded))
                .fontWeight(selected ? .semibold : .regular)
                .foregroundStyle(selected ? Color.white : .primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(selected ? Color.espresso : Color.primary.opacity(isHovered ? 0.1 : 0.05))
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

private struct FooterButton: View {
    let label: String
    let icon: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Label(label, systemImage: icon)
                .font(.system(.body))
                .foregroundStyle(isHovered ? .primary : .secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(isHovered ? Color.primary.opacity(0.08) : .clear)
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
            if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
    }
}
