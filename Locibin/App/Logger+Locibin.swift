import OSLog

extension Logger {
    private static let subsystem = "com.diasiosdev.locibin"

    /// Persistence: opening the store, saving, recovery.
    static let data = Logger(subsystem: subsystem, category: "data")

    /// Deep links and opening scanned codes.
    static let navigation = Logger(subsystem: subsystem, category: "navigation")

    /// Label PDFs and printing.
    static let labels = Logger(subsystem: subsystem, category: "labels")
}
