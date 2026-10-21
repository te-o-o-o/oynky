import Darwin

/// One process at one instant. Counters are cumulative since the process started.
public struct Proc: Equatable, Sendable {
    public var pid: Int32
    /// With the pid, tells a reused pid apart from the process that had it before.
    public var start: UInt64
    public var path: String
    /// User + system CPU time, in nanoseconds.
    public var cpu: UInt64
    /// Energy used by the process, in nanojoules. Not `ri_billed_energy`: that one only counts
    /// work billed through vouchers and stays at 0 for most apps.
    public var energy: UInt64
    /// Physical footprint in bytes: what Activity Monitor shows as Memory.
    public var memory: UInt64

    public init(pid: Int32, start: UInt64, path: String, cpu: UInt64, energy: UInt64, memory: UInt64) {
        self.pid = pid
        self.start = start
        self.path = path
        self.cpu = cpu
        self.energy = energy
        self.memory = memory
    }
}

public struct Snapshot: Sendable {
    /// Monotonic clock, in nanoseconds.
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

/// Reads every process we are allowed to read. Costs a few milliseconds for ~500 processes.
public func snapshot() -> Snapshot {
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
        // A process that exits between the two calls has no path any more: drop it.
        let length = Int(proc_pidpath(pid, &path, UInt32(path.count)))
        guard length > 0 else { continue }
        procs.append(Proc(
            pid: pid,
            start: info.ri_proc_start_abstime,
            path: String(decoding: path.prefix(length), as: UTF8.self),
            cpu: (info.ri_user_time + info.ri_system_time) * timebase.numer / timebase.denom,
            energy: info.ri_energy_nj,
            memory: info.ri_phys_footprint
        ))
    }
    return Snapshot(time: time, procs: procs, unreadable: unreadable)
}
