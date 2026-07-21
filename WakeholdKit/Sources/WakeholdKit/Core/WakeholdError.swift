import Foundation

// Errors surfaced across the kit's public API (the control client throws these).
public enum WakeholdError: Error {
    // IOKit refused to create the power assertion. Carries the raw IOReturn code (an Int32),
    // kept as a plain integer so IOKit stays confined to PowerAssertion.
    case assertionFailed(code: Int32)

    // A control-endpoint socket step (socket/bind/listen) failed. Carries which one.
    case endpointFailed(String)

    // The client could not reach the control endpoint (the app is likely not running).
    case endpointUnreachable

    // The endpoint returned a non-success status.
    case controlError(status: Int, message: String)
}
