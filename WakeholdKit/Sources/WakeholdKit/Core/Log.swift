import os

// Shared logging setup so the subsystem string lives in one place. Each type passes its own
// category, keeping entries filterable in Console and `log stream`.
public enum Log {
    public static let subsystem = "app.wakehold.Wakehold"

    public static func make(_ category: String) -> Logger {
        Logger(subsystem: subsystem, category: category)
    }
}
