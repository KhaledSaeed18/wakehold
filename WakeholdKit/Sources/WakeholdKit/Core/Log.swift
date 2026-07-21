import os

// Shared logging setup so the subsystem string lives in one place. Each type passes its own
// category, keeping entries filterable in Console and `log stream`.
enum Log {
    static let subsystem = "app.wakehold.Wakehold"

    static func make(_ category: String) -> Logger {
        Logger(subsystem: subsystem, category: category)
    }
}
