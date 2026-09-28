import Darwin
import Foundation

/// Finds running AI agent CLIs by scanning the process table.
enum AgentDetector {
    static let defaultAgents = [
        "claude", "codex", "gemini", "aider", "opencode",
        "amp", "goose", "cursor-agent", "crush", "qwen", "droid",
    ]

    /// Agents distributed as scripts show up as their interpreter, so for these
    /// we look at the script path in argv instead.
    private static let interpreters: Set<String> = [
        "node", "bun", "deno", "python", "python3", "ruby",
    ]

    /// Returns agent name → number of running processes.
    static func scan(for agents: Set<String>) -> [String: Int] {
        guard !agents.isEmpty else { return [:] }
        let ownPID = getpid()
        var found: [String: Int] = [:]

        for pid in allPIDs() where pid > 0 && pid != ownPID {
            if let agent = match(pid: pid, agents: agents) {
                found[agent, default: 0] += 1
            }
        }
        return found
    }

    private static func match(pid: pid_t, agents: Set<String>) -> String? {
        let name = processName(pid)
        if agents.contains(name) { return name }

        // Interpreters run agent scripts; version-named binaries (e.g. Claude
        // Code's native installer) are launched through a symlink in argv[0].
        let isInterpreter = interpreters.contains(name)
        let looksVersioned = name.first?.isNumber ?? false
        guard isInterpreter || looksVersioned else { return nil }

        let args = arguments(of: pid)
        var candidates: [String] = []
        if let argv0 = args.first { candidates.append(argv0) }
        if isInterpreter, let script = args.dropFirst().first(where: { !$0.hasPrefix("-") }) {
            candidates.append(script)
        }
        for candidate in candidates {
            let base = (candidate as NSString).lastPathComponent
            let stem = (base as NSString).deletingPathExtension
            if agents.contains(base) { return base }
            if agents.contains(stem) { return stem }
        }
        return nil
    }

    private static func allPIDs() -> [pid_t] {
        let estimate = proc_listallpids(nil, 0)
        guard estimate > 0 else { return [] }
        var pids = [pid_t](repeating: 0, count: Int(estimate) + 64)
        let count = pids.withUnsafeMutableBufferPointer { buffer in
            proc_listallpids(buffer.baseAddress, Int32(buffer.count * MemoryLayout<pid_t>.size))
        }
        guard count > 0 else { return [] }
        return Array(pids.prefix(Int(count)))
    }

    private static func processName(_ pid: pid_t) -> String {
        var buffer = [CChar](repeating: 0, count: 256)
        guard proc_name(pid, &buffer, UInt32(buffer.count)) > 0 else { return "" }
        return String(cString: buffer)
    }

    /// Reads argv via KERN_PROCARGS2. Only works for processes owned by the
    /// current user, which is exactly the set we care about.
    private static func arguments(of pid: pid_t) -> [String] {
        var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
        var size = 0
        guard sysctl(&mib, 3, nil, &size, nil, 0) == 0, size > 0 else { return [] }
        var buffer = [UInt8](repeating: 0, count: size)
        guard sysctl(&mib, 3, &buffer, &size, nil, 0) == 0,
              size > MemoryLayout<Int32>.size else { return [] }

        // Layout: argc (Int32), exec path, NUL padding, argv[0..argc), envp...
        let argc = buffer.withUnsafeBytes { $0.loadUnaligned(as: Int32.self) }
        var i = MemoryLayout<Int32>.size
        while i < size && buffer[i] != 0 { i += 1 }
        while i < size && buffer[i] == 0 { i += 1 }

        var args: [String] = []
        while args.count < Int(argc) && i < size {
            let start = i
            while i < size && buffer[i] != 0 { i += 1 }
            args.append(String(decoding: buffer[start..<i], as: UTF8.self))
            i += 1
        }
        return args
    }
}
