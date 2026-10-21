import AppKit
import IOKit.ps
import OynkyCore
import ServiceManagement

// ponytail: inline English/French pairs; move to Localizable.strings once they outgrow a handful.
private let french = Locale.preferredLanguages.first?.hasPrefix("fr") == true
private func tr(_ english: String, _ frenchText: String) -> String { french ? frenchText : english }

@MainActor
final class MenuBar: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    let menu = NSMenu()
    let history = History(directory: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appending(path: "oynky"))
    var monitor = Monitor()
    var timer: Timer?
    var pressure: DispatchSourceMemoryPressure?
    var menuOpen = false
    var lastHour: [AppUsage] = []

    static func run() {
        let app = NSApplication.shared
        let bar = MenuBar()
        app.delegate = bar  // weak: the local keeps it alive for as long as run() runs
        app.setActivationPolicy(.accessory)  // no Dock icon, even under `swift run`
        withExtendedLifetime(bar) { app.run() }
    }

    func applicationDidFinishLaunching(_: Notification) {
        // Placeholder until the real design.
        item.button?.image = NSImage(systemSymbolName: "gauge.with.dots.needle.33percent", accessibilityDescription: "oynky")
        menu.delegate = self
        menu.autoenablesItems = false  // rows have no action but must not look disabled
        item.menu = menu

        // Events only trigger a sample now; the next tick is scheduled from there.
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.sample() }
        }
        let source = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical], queue: .main)
        source.setEventHandler { [weak self] in MainActor.assumeIsolated { self?.sample() } }
        source.resume()
        pressure = source

        sample()
    }

    func sample() {
        if let minute = monitor.add(snapshot()) {
            do { try history.append(minute, at: Date()) } catch { NSLog("oynky: history: \(error)") }
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

    // MARK: menu

    func menuWillOpen(_: NSMenu) {
        menuOpen = true
        lastHour = summary(history.records(since: Date(timeIntervalSinceNow: -3600)))
        fill()
        schedule()
    }

    func menuDidClose(_: NSMenu) {
        menuOpen = false
        schedule()
    }

    func fill() {
        menu.removeAllItems()
        if monitor.live.isEmpty {
            menu.addItem(withTitle: tr("Measuring…", "Mesure en cours…"), action: nil, keyEquivalent: "").isEnabled = false
        } else {
            section(tr("Now", "En ce moment"), ranked(monitor.live, by: .cpu)) { [percent($0.cpu), milliwatts($0.watts)] }
            section(tr("Memory", "Mémoire"), ranked(monitor.live, by: .memory)) { ["", bytes($0.memory)] }  // same right edge as the energy column
        }
        if !lastHour.isEmpty {
            section(tr("Last hour", "Dernière heure"), ranked(lastHour, by: .cpu)) { [percent($0.cpu), milliwatts($0.watts)] }
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

    /// A header and the top 5 apps, values right-aligned in columns.
    func section(_ title: String, _ apps: [AppUsage], values: (AppUsage) -> [String]) {
        menu.addItem(.sectionHeader(title: title))
        let style = NSMutableParagraphStyle()
        style.tabStops = [NSTextTab(textAlignment: .right, location: 250), NSTextTab(textAlignment: .right, location: 320)]
        let font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        for app in apps.prefix(5) {
            let row = NSMenuItem()
            let text = ([String(app.name.prefix(28))] + values(app)).joined(separator: "\t")
            row.attributedTitle = NSAttributedString(string: text, attributes: [.paragraphStyle: style, .font: font])
            menu.addItem(row)
        }
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
