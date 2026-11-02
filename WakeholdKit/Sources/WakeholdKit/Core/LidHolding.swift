import Foundation

// What WakeController drives to keep the Mac awake with the lid closed. A protocol so tests can
// watch the reconcile output without touching the system's sleep setting.
@MainActor
public protocol LidHolding: AnyObject {
    func setHeld(_ held: Bool)
}
