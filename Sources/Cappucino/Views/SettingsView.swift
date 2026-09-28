import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var manager: AwakeManager
    @State private var newAgent = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Settings")
                .font(.system(.title3, design: .rounded))
                .fontWeight(.bold)

            GroupBox("General") {
                Toggle("Launch at login", isOn: Binding(
                    get: { manager.launchAtLogin },
                    set: { manager.setLaunchAtLogin($0) }
                ))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(4)
            }

            GroupBox("Agents") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Process names that keep the Mac awake while running")
                        .font(.system(.caption2))
                        .foregroundStyle(.tertiary)

                    FlowLayout(spacing: 6) {
                        ForEach(manager.agentNames, id: \.self) { name in
                            AgentChip(name: name, running: manager.runningAgents.contains(name)) {
                                manager.agentNames.removeAll { $0 == name }
                            }
                        }
                    }

                    HStack {
                        TextField("Add process name", text: $newAgent)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit(addAgent)
                        Button("Add", action: addAgent)
                            .disabled(newAgent.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    .controlSize(.small)

                    Button("Restore Defaults") {
                        manager.agentNames = AgentDetector.defaultAgents
                    }
                    .controlSize(.small)
                }
                .padding(4)
            }

            GroupBox("After Agents Finish") {
                VStack(alignment: .leading, spacing: 4) {
                    Picker("", selection: $manager.lingerMinutes) {
                        ForEach(AwakeManager.lingerOptions, id: \.self) { minutes in
                            Text(minutes == 0 ? "None" : "\(minutes)m").tag(minutes)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    Text("Stay awake a little longer in case you start the next task")
                        .font(.system(.caption2))
                        .foregroundStyle(.tertiary)
                }
                .padding(4)
            }
        }
        .padding(20)
        .frame(width: 340)
    }

    private func addAgent() {
        let name = newAgent.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        if !manager.agentNames.contains(name) {
            manager.agentNames.append(name)
        }
        newAgent = ""
    }
}

private struct AgentChip: View {
    let name: String
    let running: Bool
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            if running {
                Circle().fill(Color.crema).frame(width: 5, height: 5)
            }
            Text(name)
                .font(.system(.caption, design: .monospaced))
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Capsule().fill(Color.primary.opacity(0.07)))
    }
}

/// Wraps children onto multiple lines.
private struct FlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row { var indices: [Int] = []; var width: CGFloat = 0; var height: CGFloat = 0 }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = [Row()]
        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)
            let extra = rows[rows.count - 1].indices.isEmpty ? size.width : spacing + size.width
            if rows[rows.count - 1].width + extra > width && !rows[rows.count - 1].indices.isEmpty {
                rows.append(Row())
                rows[rows.count - 1].width = size.width
            } else {
                rows[rows.count - 1].width += extra
            }
            rows[rows.count - 1].indices.append(index)
            rows[rows.count - 1].height = max(rows[rows.count - 1].height, size.height)
        }
        return rows.filter { !$0.indices.isEmpty }
    }
}
