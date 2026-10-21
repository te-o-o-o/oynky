import Darwin

/// One process at one instant. Counters are cumulative since the process started.
public struct Proc: Equatable, Sendable {
    public var pid: Int32
    /// The parent process, read once like the path: what tells "launched by Ghostty" apart from a service.
    public var ppid: Int32
    /// Launch time on the snapshot clock (ns since boot): tells a reused pid apart, and gives the process's age.
    public var start: UInt64
    public var path: String
    /// Derived from the path once per process, not on every snapshot: see `appName(path:)` and `isApple(path:)`.
    public var app: String
    public var apple: Bool
    /// User + system CPU time, in nanoseconds.
    public var cpu: UInt64
    /// Energy used by the process, in nanojoules. Not `ri_billed_energy`: that one only counts
    /// work billed through vouchers and stays at 0 for most apps.
    public var energy: UInt64
    /// Physical footprint in bytes: what Activity Monitor shows as Memory.
    public var memory: UInt64

    public init(pid: Int32, ppid: Int32 = 1, start: UInt64, path: String, cpu: UInt64, energy: UInt64, memory: UInt64) {
        self.pid = pid
        self.ppid = ppid
        self.start = start
        self.path = path
        self.app = appName(path: path)
        self.apple = isApple(path: path)
        self.cpu = cpu
        self.energy = energy
        self.memory = memory
    }
}

public struct Snapshot: Sendable {
    /// Monotonic clock, in nanoseconds since boot (the clock `Proc.start` is on).
    public var time: UInt64
    public var procs: [Proc]
    /// Processes we may not read: other users' (root daemons) need oynky to run as root.
    public var unreadable: Int

    public init(time: UInt64, procs: [Proc], unreadable: Int = 0) {
        self.time = time
        self.procs = procs
        self.unreadable = unreadable
    }
}

/// rusage times are mach ticks, not nanoseconds: 1 tick = 125/3 ns on Apple Silicon, 1 ns on Intel.
private let timebase: (numer: UInt64, denom: UInt64) = {
    var t = mach_timebase_info_data_t()
    mach_timebase_info(&t)
    return (UInt64(t.numer), UInt64(t.denom))
}()

/// Reads every process we are allowed to read. Processes already in `previous` keep their path
/// and app name: those only change with the process, and are the most costly part to read.
/// A few milliseconds for ~400 processes, a third of that when nearly all are known.
public func snapshot(after previous: Snapshot? = nil) -> Snapshot {
    let known = Dictionary((previous?.procs ?? []).map { ($0.pid, $0) }, uniquingKeysWith: { first, _ in first })
    let time = clock_gettime_nsec_np(CLOCK_UPTIME_RAW)
    let size = MemoryLayout<pid_t>.size
    // The first call only returns the size needed; leave room for processes started in between.
    var pids = [pid_t](repeating: 0, count: Int(proc_listpids(UInt32(PROC_ALL_PIDS), 0, nil, 0)) / size + 64)
    let count = Int(proc_listpids(UInt32(PROC_ALL_PIDS), 0, &pids, Int32(pids.count * size))) / size

    var procs: [Proc] = []
    var unreadable = 0
    var path = [UInt8](repeating: 0, count: 4 * Int(MAXPATHLEN))  // PROC_PIDPATHINFO_MAXSIZE
    for pid in pids.prefix(count) where pid > 0 {
        var info = rusage_info_v6()
        let status = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { proc_pid_rusage(pid, RUSAGE_INFO_V6, $0) }
        }
        guard status == 0 else {
            unreadable += 1
            continue
        }
        let start = info.ri_proc_start_abstime * timebase.numer / timebase.denom
        let cpu = (info.ri_user_time + info.ri_system_time) * timebase.numer / timebase.denom
        if var p = known[pid], p.start == start {
            p.cpu = cpu
            p.energy = info.ri_energy_nj
            p.memory = info.ri_phys_footprint
            procs.append(p)
            continue
        }
        // A process that exits between the two calls has no path any more: drop it.
        let length = Int(proc_pidpath(pid, &path, UInt32(path.count)))
        guard length > 0 else { continue }
        let ppid = parent(of: pid)?.ppid ?? 1
        let p = String(decoding: path.prefix(length), as: UTF8.self)
        var proc = Proc(pid: pid, ppid: ppid, start: start, path: p, cpu: cpu, energy: info.ri_energy_nj, memory: info.ri_phys_footprint)
        // A file named like a version (Claude Code's `2.1.306`) is named after its command instead,
        // which also keeps every version in one group. Only then is the command line read.
        if !proc.app.contains(where: \.isLetter), let argv0 = arguments(pid: pid)?.first, let name = commandName(executable: p, argv0: argv0) {
            proc.app = name
        }
        procs.append(proc)
    }
    return Snapshot(time: time, procs: procs, unreadable: unreadable)
}
