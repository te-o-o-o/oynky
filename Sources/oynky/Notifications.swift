import AppKit
import OynkyCore
@preconcurrency import UserNotifications

/// Speaks only when a finding is new, at most once a day per finding. Silent under `swift run`:
/// notifications need a real .app (no bundle, no notification center).
extension MenuBar: UNUserNotificationCenterDelegate {
    static let toldKey = "told"

    func setUpNotifications() {
        guard Bundle.main.bundleIdentifier != nil else { return }
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert]) { _, error in
            if let error { NSLog("oynky: notifications: \(error)") }
        }
    }

    func tell() {
        guard Bundle.main.bundleIdentifier != nil else { return }
        let now = Date()
        var news: [String: (title: String, body: String)] = [:]
        for app in hogs {
            news["hog:\(app.name)"] = (
                tr("\(app.name) is busy in the background", "\(app.name) travaille en arrière-plan"),
                tr("\(percent(app.cpu)) CPU on average for 30 minutes, while you were not using it.",
                   "\(percent(app.cpu)) de CPU en moyenne depuis 30 minutes, sans que vous l'utilisiez.")
            )
        }
        for climb in climbs {
            news["climb:\(climb.name)"] = (
                tr("\(climb.name)'s memory keeps growing", "La mémoire de \(climb.name) ne redescend pas"),
                tr("From \(bytes(climb.from)) to \(bytes(climb.to)) in 6 hours, never coming back down.",
                   "De \(bytes(climb.from)) à \(bytes(climb.to)) en 6 heures, sans jamais redescendre.")
            )
        }
        // Only reports from the last day: a first launch must not dig up the whole week.
        for report in flagged where report.date > now - 86400 {
            news["report:\(report.name):\(report.event)"] = (tr("macOS flagged \(report.name)", "macOS a signalé \(report.name)"), report.detail)
        }
        for install in installed {
            let running = monitor.last.map { longLived($0, app: install.name) } ?? 0
            guard running > 0 else { continue }
            news["install:\(install.name)"] = (
                tr("\(install.name) keeps running", "\(install.name) tourne en permanence"),
                tr("Installed \(ago(install.added)), \(running) of its processes have been running for over an hour.",
                   "Installée \(ago(install.added)), \(running) de ses processus tournent depuis plus d'une heure.")
            )
        }

        var told = UserDefaults.standard.dictionary(forKey: Self.toldKey) as? [String: Date] ?? [:]
        for key in due(Array(news.keys), told: told, now: now) {
            let content = UNMutableNotificationContent()
            content.title = news[key]!.title
            content.body = news[key]!.body
            UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: key, content: content, trigger: nil))
            told[key] = now
        }
        // Forget what is long past, so the stored list stays small.
        UserDefaults.standard.set(told.filter { now.timeIntervalSince($0.value) < 7 * 86400 }, forKey: Self.toldKey)
    }

    /// A click on a notification opens the menu, where the finding is.
    nonisolated func userNotificationCenter(_: UNUserNotificationCenter, didReceive _: UNNotificationResponse) async {
        await MainActor.run { item.button?.performClick(nil) }
    }
}
