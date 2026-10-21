import OynkyCore
import Testing

@Test func energyAddsUpMinutesOfWatts() {
    // An hour at 2 W is 2 Wh.
    let records = minutes(60) { _ in AppUsage(name: "Zen", cpu: 10, watts: 2, memory: 0, processes: 1) }
    #expect(abs(energy(records)["Zen"]! - 2) < 0.000001)
}

@Test func theBatteryReadsSensibleFigures() {
    // Nil on a Mac without a battery (CI runners): nothing to check then.
    guard let battery = Battery.read() else { return }
    #expect((20...150).contains(battery.capacity))
    if let draw = battery.draw { #expect((0...200).contains(draw)) }
}
