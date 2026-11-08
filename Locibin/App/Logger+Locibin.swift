import OSLog

extension Logger {
    private static let subsystem = "com.diasiosdev.locibin"

    /// Persistence: opening the store, saving, recovery.
    static let data = Logger(subsystem: subsystem, category: "data")
}
