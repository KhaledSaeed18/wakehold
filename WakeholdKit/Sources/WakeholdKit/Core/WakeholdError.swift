import Foundation

// Core subsystem errors. Other subsystems (service, sessions) get their own error enums.
enum WakeholdError: Error {
    // IOKit refused to create the power assertion. Carries the raw IOReturn code (an Int32),
    // kept as a plain integer so IOKit stays confined to PowerAssertion.
    case assertionFailed(code: Int32)
}
