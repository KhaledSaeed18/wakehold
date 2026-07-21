import Foundation

// A snapshot of the machine's power situation.
public struct PowerState: Equatable {
    public let isOnBattery: Bool
    public let batteryPercent: Int?          // nil on machines without a battery
    public let isLowPowerMode: Bool

    public init(isOnBattery: Bool, batteryPercent: Int?, isLowPowerMode: Bool) {
        self.isOnBattery = isOnBattery
        self.batteryPercent = batteryPercent
        self.isLowPowerMode = isLowPowerMode
    }
}

// The user's power policy: when should sessions stop holding the Mac awake. Battery drain is the
// category's top complaint, so these matter even though they are opt-in.
public struct PowerGuardrail: Equatable {
    public var releaseOnBattery: Bool
    public var batteryThreshold: Int?        // release below this percent; nil = no threshold
    public var releaseOnLowPowerMode: Bool

    public init(releaseOnBattery: Bool = false, batteryThreshold: Int? = nil, releaseOnLowPowerMode: Bool = false) {
        self.releaseOnBattery = releaseOnBattery
        self.batteryThreshold = batteryThreshold
        self.releaseOnLowPowerMode = releaseOnLowPowerMode
    }

    public func suppresses(_ state: PowerState) -> Bool {
        if releaseOnLowPowerMode, state.isLowPowerMode { return true }
        if releaseOnBattery, state.isOnBattery { return true }
        if let threshold = batteryThreshold, let percent = state.batteryPercent, percent < threshold { return true }
        return false
    }
}
