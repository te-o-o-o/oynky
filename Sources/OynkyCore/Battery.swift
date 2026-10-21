import Foundation
import IOKit

/// The battery as IOKit's AppleSmartBattery reports it (what `ioreg -rn AppleSmartBattery` shows).
/// Readable without root. Nil on a Mac without a battery.
public struct Battery: Sendable {
    /// What a full charge holds today, in watt-hours: an aged battery holds less than it was designed for.
    public var capacity: Double
    /// What the Mac draws from the battery right now, in watts; nil on mains power.
    public var draw: Double?

    public static func read() -> Battery? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        func value(_ key: String) -> Any? {
            IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
        }
        // Apple Silicon keeps the full charge in BatteryData; Intel Macs expose AppleRawMaxCapacity (not verified on Intel).
        let milliampHours = (value("BatteryData") as? [String: Any])?["FullChargeCapacity"] as? Int ?? value("AppleRawMaxCapacity") as? Int
        guard let milliampHours, let millivolts = value("Voltage") as? Int, milliampHours > 0 else { return nil }
        let volts = Double(millivolts) / 1000
        // Negative while discharging. Only meaningful off mains: plugged in, it is the charging current.
        let milliamps = value("InstantAmperage") as? Int ?? value("Amperage") as? Int ?? 0
        let onBattery = value("ExternalConnected") as? Bool == false
        return Battery(
            capacity: Double(milliampHours) / 1000 * volts,
            draw: onBattery && milliamps < 0 ? Double(-milliamps) / 1000 * volts : nil
        )
    }
}

/// Energy used per app over the records, in watt-hours: each record is one minute at its average watts.
public func energy(_ records: [Record]) -> [String: Double] {
    records.reduce(into: [:]) { wh, r in wh[r.app.name, default: 0] += r.app.watts / 60 }
}
