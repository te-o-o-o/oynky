import AppKit
import IOKit.ps
import OynkyCore
import ServiceManagement

// ponytail: inline English/French pairs; move to Localizable.strings once they outgrow a handful.
let french = Locale.preferredLanguages.first?.hasPrefix("fr") == true
func tr(_ english: String, _ frenchText: String) -> String { french ? frenchText : english }

@MainActor
final class MenuBar: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    let menu = NSMenu()
    let history = History(directory: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appending(path: "oynky"))
    var monitor = Monitor()
    var timer: Timer?
    var menuOpen = false
    var alerting = false
    var sources: [any DispatchSourceProtocol] = []

    /// The last 6 hours of history, kept in memory for the rules that run every minute.
    var recent: [Record] = []
    /// When each app was last brought to the front: what "in use" means.
    var front: [String: Date] = [:]
    var hogs: [AppUsage] = []
    var climbs: [Climb] = []
    var installed: [Install] = []
    var flagged: [Report] = []
    var lastHour: [AppUsage] = []
    var sinceInstall: [String: AppUsage] = [:]
    var battery = Battery.read()
    /// Watt-hours per app over the last 24 hours.
    var day: [String: Double] = [:]
    static let drawKey = "draw"
    /// For the grey line under each name: a path per app, the app that launched it, the services index.
    var paths: [String: String] = [:]
    var launchedBy: [String: String] = [:]
    var services: [String: String] = [:]
    var explained: [String: (line: String?, tip: String?, live: Bool)] = [:]

    static let window: TimeInterval = 6 * 3600
    static let week: TimeInterval = 7 * 86400

    static func run() {
        let app = NSApplication.shared
        let bar = MenuBar()
        app.delegate = bar  // weak: the local keeps it alive for as long as run() runs
        app.setActivationPolicy(.accessory)  // no Dock icon, even under `swift run`
        withExtendedLifetime(bar) { app.run() }
    }

    func applicationDidFinishLaunching(_: Notification) {
        menu.delegate = self
        menu.autoenablesItems = false  // rows have no action but must not look disabled
        item.menu = menu

        recent = history.records(since: Date(timeIntervalSinceNow: -Self.window))
        if let path = NSWorkspace.shared.frontmostApplication?.executableURL?.path { front[appName(path: path)] = Date() }

        // Events only trigger work now; the next tick is scheduled from there.
        let events = NSWorkspace.shared.notificationCenter
        events.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.sample() }
        }
        events.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            let path = (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.executableURL?.path
            MainActor.assumeIsolated { if let path { self?.front[appName(path: path)] = Date() } }
        }
        let pressure = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical], queue: .main)
        pressure.setEventHandler { [weak self] in MainActor.assumeIsolated { self?.sample() } }
        pressure.resume()
        sources.append(pressure)
        for (folder, _) in installPlaces { watch(folder) }
        watch(reportsFolder)

        setUpNotifications()
        readClues()
        judge()
        sample()
    }

    func sample() {
        if let minute = monitor.add(snapshot(after: monitor.last)) {
            let now = Date()
            do { try history.append(minute, at: now) } catch { NSLog("oynky: history: \(error)") }
            recent = recent.filter { $0.time > now - Self.window } + minute.filter(History.worthKeeping).map { Record(time: now, app: $0) }
            judge()
            readBattery()
        }
        if menuOpen { fill() }
        schedule()
    }

    /// Every second while the menu is open, every 5 s on mains power, every 15 s on battery.
    func schedule() {
        timer?.invalidate()
        let interval: TimeInterval = menuOpen ? 1 : onBattery() ? 15 : 5
        let next = Timer(timeInterval: interval, repeats: false) { [weak self] _ in MainActor.assumeIsolated { self?.sample() } }
        next.tolerance = interval / 5  // lets macOS wake us together with other timers
        RunLoop.main.add(next, forMode: .common)  // .common: keeps firing while the menu is open
        timer = next
    }

    func onBattery() -> Bool {
        let info = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        return IOPSGetProvidingPowerSourceType(info)?.takeUnretainedValue() as String? == kIOPMBatteryPowerKey
    }

    // MARK: findings

    /// A folder gaining or losing an entry re-reads installs and reports. A missing folder
    /// (no ~/Applications) or one we may not read is simply not watched.
    func watch(_ folder: URL) {
        let fd = open(folder.path, O_EVTONLY)
        guard fd >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: .write, queue: .main)
        source.setEventHandler { [weak self] in MainActor.assumeIsolated { self?.readClues() } }
        source.setCancelHandler { close(fd) }
        source.resume()
        sources.append(source)
    }

    func readClues() {
        let since = Date(timeIntervalSinceNow: -Self.week)
        installed = installs(since: since)
        // Newest first: keep the latest report of each app and kind, macOS repeats them.
        var seen = Set<String>()
        flagged = reports(since: since).filter { !$0.apple && seen.insert($0.name + "\t" + $0.event).inserted }
        updateIcon()
        tell()
    }

    func judge() {
        let now = Date()
        var inUse = Set(front.filter { $0.value > now - 30 * 60 }.keys)
        if let path = NSWorkspace.shared.frontmostApplication?.executableURL?.path { inUse.insert(appName(path: path)) }
        // What an app in use launched is in use too: a build or `node` running in the terminal you are typing in.
        if let last = monitor.last { inUse.formUnion(launchers(in: last).filter { inUse.contains($0.value) }.keys) }
        hogs = backgroundHogs(recent, inUse: inUse, now: now)
        climbs = memoryClimbs(recent, now: now)
        updateIcon()
        tell()
    }

    /// Placeholder symbols until the real design: the needle goes up when something is worth a look.
    func updateIcon() {
        let fresh = flagged.contains { $0.date > Date(timeIntervalSinceNow: -86400) }
        let alert = !hogs.isEmpty || !climbs.isEmpty || fresh
        // Only on a change: every new image makes menu bar managers (Thaw, Bartender) query the item again.
        guard alert != alerting || item.button?.image == nil else { return }
        alerting = alert
        item.button?.image = NSImage(systemSymbolName: alert ? "gauge.with.dots.needle.67percent" : "gauge.with.dots.needle.33percent", accessibilityDescription: "oynky")
    }

    /// The Mac's usual draw on battery, averaged over the minutes it ran on battery: what turns
    /// an app's watt-hours into minutes of battery.
    func readBattery() {
        battery = Battery.read()
        guard let draw = battery?.draw else { return }
        let usual = UserDefaults.standard.object(forKey: Self.drawKey) as? Double
        UserDefaults.standard.set(usual.map { $0 * 0.95 + draw * 0.05 } ?? draw, forKey: Self.drawKey)
    }

    // MARK: menu

    func menuWillOpen(_: NSMenu) {
        menuOpen = true
        let now = Date()
        lastHour = summary(recent.filter { $0.time > now - 3600 })
        // ponytail: reads up to 7 days of history on each open; cache it if opening ever feels slow.
        let records = history.records(since: min(now - 86400, installed.map(\.added).min() ?? now))
        day = energy(records.filter { $0.time > now - 86400 })
        sinceInstall = [:]
        for install in installed {
            sinceInstall[install.name] = summary(records.filter { $0.time >= install.added }).first { $0.name == install.name }
        }
        if let last = monitor.last {
            for p in last.procs where paths[p.app] == nil { paths[p.app] = p.path }
            launchedBy = launchers(in: last)
        }
        if services.isEmpty { services = launchServices() }  // ~40 ms for ~850 plists, once
        fill()
        schedule()
    }

    func menuDidClose(_: NSMenu) {
        menuOpen = false
        schedule()
    }

    func fill() {
        menu.removeAllItems()

        if hogs.isEmpty && climbs.isEmpty && flagged.isEmpty {
            menu.addItem(withTitle: tr("Nothing suspicious", "Rien de suspect"), action: nil, keyEquivalent: "").isEnabled = false
        }
        section(tr("Busy in the background", "Actives en arrière-plan"), ranked(hogs, by: .cpu).map { ($0.name, [percent($0.cpu), milliwatts($0.watts)], nil) })
        section(tr("Memory keeps growing", "Mémoire qui ne redescend pas"), climbs.map { ($0.name, ["", "\(bytes($0.from)) → \(bytes($0.to))"], nil) })
        section(tr("Flagged by macOS", "Signalées par macOS"), flagged.map { report in
            (report.name, ["", event(report.event)], "\(ago(report.date)): \(report.detail)")
        })
        section(tr("Installed recently", "Installées récemment"), installed.map { install in
            let use = sinceInstall[install.name]
            let running = monitor.last.map { longLived($0, app: install.name) } ?? 0
            var note = tr("Installed", "Installée") + " " + ago(install.added)
            if install.kind == .daemon { note += tr(". Runs as root: not measured.", ". Tourne en root : non mesurée.") }
            if running > 0 { note += tr(". \(running) processes running for over an hour.", ". \(running) processus actifs depuis plus d'une heure.") }
            return (install.name, [percent(use?.cpu ?? 0), milliwatts(use?.watts ?? 0)], note)
        })

        if monitor.live.isEmpty {
            menu.addItem(withTitle: tr("Measuring…", "Mesure en cours…"), action: nil, keyEquivalent: "").isEnabled = false
        } else {
            section(tr("Now", "En ce moment"), ranked(monitor.live, by: .cpu).map { ($0.name, [percent($0.cpu), milliwatts($0.watts)], nil) })
            section(tr("Memory", "Mémoire"), ranked(monitor.live, by: .memory).map { ($0.name, ["", bytes($0.memory)], nil) })
        }
        section(tr("Last hour", "Dernière heure"), ranked(lastHour, by: .cpu).map { ($0.name, [percent($0.cpu), milliwatts($0.watts)], nil) })
        if let battery {
            let draw = UserDefaults.standard.object(forKey: Self.drawKey) as? Double
            let tip = draw.map { tr("Minutes at the Mac's usual draw on battery, \(String(format: "%.1f", $0)) W.",
                                    "Minutes au rythme habituel du Mac sur batterie, \(String(format: "%.1f", $0)) W.") }
                ?? tr("Minutes appear once the Mac has run on battery.", "Les minutes apparaissent quand le Mac a tourné sur batterie.")
            section(tr("Battery, last 24 hours", "Batterie, dernières 24 heures"), day.sorted { $0.value > $1.value }.map { name, wh in
                (name, [charge(wh / battery.capacity), draw.map { minutes(wh / $0) } ?? ""], tip)
            })
        }

        menu.addItem(.separator())
        // Login items need a real .app: hidden under `swift run`.
        if Bundle.main.bundleIdentifier != nil {
            let login = menu.addItem(withTitle: tr("Open at Login", "Ouvrir à la connexion"), action: #selector(toggleOpenAtLogin), keyEquivalent: "")
            login.target = self
            login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        }
        menu.addItem(withTitle: tr("Quit oynky", "Quitter oynky"), action: #selector(quit), keyEquivalent: "q").target = self
    }

    /// A header and up to 5 rows: the name, then values right-aligned in two columns. Nothing when empty.
    func section(_ title: String, _ rows: [(name: String, values: [String], tip: String?)]) {
        guard !rows.isEmpty else { return }
        menu.addItem(.sectionHeader(title: title))
        let style = NSMutableParagraphStyle()
        style.tabStops = [NSTextTab(textAlignment: .right, location: 250), NSTextTab(textAlignment: .right, location: 330)]
        let font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        let small: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize), .foregroundColor: NSColor.secondaryLabelColor]
        for row in rows.prefix(5) {
            let item = NSMenuItem()
            let text = NSMutableAttributedString(string: ([String(row.name.prefix(28))] + row.values).joined(separator: "\t"),
                                                 attributes: [.paragraphStyle: style, .font: font])
            let about = explain(row.name)
            if let line = about.line { text.append(NSAttributedString(string: "\n" + line, attributes: small)) }
            item.attributedTitle = text
            item.toolTip = [row.tip, about.tip].compactMap { $0 }.joined(separator: "\n\n")
            menu.addItem(item)
        }
    }

    /// The grey line under a name (what it is · who made it · how it starts) and the details for its tooltip.
    /// Cached per app: the signature is the costly part, and the menu refills every second.
    func explain(_ name: String) -> (line: String?, tip: String?) {
        if let known = explained[name], paths[name] == nil || known.live { return (known.line, known.tip) }
        let path = paths[name]
        let gloss = glossary[name]
        let program = path.map { URL(filePath: $0).lastPathComponent } ?? name
        let what = gloss.map { tr($0.what.en, $0.what.fr) } ?? manSummary(program).map { $0.prefix(1).uppercased() + $0.dropFirst() }
        // Who signed it, from the outermost bundle when there is one (helpers share their app's signature).
        let who = path.map { path in
            let bundle = path.firstRange(of: ".app/").map { String(path[..<$0.lowerBound]) + ".app" } ?? path
            return signer(path: bundle) ?? tr("unsigned", "non signée")
        }
        let service = path.flatMap { services[$0] }
        let how = launchedBy[name].map { tr("launched by \($0)", "lancée par \($0)") }
            ?? (service != nil && who != "Apple" ? tr("starts on its own", "se lance toute seule") : nil)
        let line = [what, who, how].compactMap { $0 }.joined(separator: " · ")
        let tip = [gloss?.note.map { tr($0.en, $0.fr) }, service.map { tr("Service: ", "Service : ") + $0 }, path].compactMap { $0 }.joined(separator: "\n")
        let about = (line: line.isEmpty ? nil : line, tip: tip.isEmpty ? nil : tip, live: path != nil)
        explained[name] = about
        return (about.line, about.tip)
    }

    /// Share of a full charge: "4 %", "0.3 %".
    func charge(_ share: Double) -> String {
        String(format: share < 0.01 ? "%.1f %%" : "%.0f %%", share * 100)
    }

    /// "25 min", "1 h 10".
    func minutes(_ hours: Double) -> String {
        let total = Int((hours * 60).rounded())
        return total < 60 ? "\(total) min" : String(format: "%d h %02d", total / 60, total % 60)
    }

    func ago(_ date: Date) -> String {
        let relative = RelativeDateTimeFormatter()
        relative.locale = Locale(identifier: french ? "fr" : "en")
        return relative.localizedString(for: date, relativeTo: Date())
    }

    func event(_ name: String) -> String {
        guard french else { return name }
        return ["disk writes": "écritures disque", "cpu usage": "CPU", "wakeups": "réveils"][name] ?? name
    }

    @objc func toggleOpenAtLogin() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled { try service.unregister() } else { try service.register() }
        } catch {
            NSLog("oynky: open at login: \(error)")
        }
    }

    @objc func quit() {
        NSApp.terminate(nil)
    }
}
