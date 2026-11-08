import Foundation
import Observation

/// Settings: backup export / import and app info (design 2.2, screen 12).
@Observable
final class SettingsViewModel {
    /// Ready-made backup file for the Share button; refreshed when the screen opens.
    private(set) var exportURL: URL?
    var isImporterPresented = false
    var alert: AlertState?
    private(set) var hasSnapshot: Bool

    let versionText: String

    private let backup: BackupService
    private let router: AppRouter
    private let formatter: ContentsFormatter
    private let locale: Locale
    private var pendingImportURL: URL?

    init(
        backup: BackupService,
        router: AppRouter,
        pendingImportURL: URL? = nil,
        locale: Locale = .current,
        bundle: Bundle = .main
    ) {
        self.backup = backup
        self.router = router
        self.pendingImportURL = pendingImportURL
        self.locale = locale
        self.formatter = ContentsFormatter(locale: locale)
        self.hasSnapshot = backup.hasSnapshot
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        self.versionText = "\(version) (\(build))"
    }

    /// Prepares the export file and handles a backup opened from the Files app.
    func onAppear() {
        prepareExport()
        if let url = pendingImportURL {
            pendingImportURL = nil
            importFileSelected(url)
        }
    }

    func importTapped() {
        isImporterPresented = true
    }

    func importFileSelected(_ url: URL) {
        do {
            let document = try backup.readBackup(at: url)
            confirmReplace(with: document)
        } catch {
            alert = .error(error)
        }
    }

    func importFailed(_ error: Error) {
        alert = .error(BackupError.couldNotRead)
    }

    func restoreSnapshotTapped() {
        do {
            confirmReplace(with: try backup.readSnapshot())
        } catch {
            alert = .error(error)
        }
    }

    func doneTapped() {
        router.dismissSheet()
    }

    // MARK: - Private

    private func prepareExport() {
        do {
            exportURL = try backup.exportFile()
        } catch {
            exportURL = nil
        }
    }

    private func confirmReplace(with document: BackupDocument) {
        let incoming = formatter.summary(LocationContents(locations: document.counts.locations, items: document.counts.items))
        let current = backup.currentCounts()
        let currentText = formatter.summary(LocationContents(locations: current.locations, items: current.items))
        let date = document.exportedAt.formatted(Date.FormatStyle(date: .long, time: .omitted).locale(locale))

        alert = AlertState(
            title: String(localized: "Replace All Data?", comment: "Import confirmation title"),
            message: String(localized: "The file has \(incoming), saved on \(date). Your current data (\(currentText)) will be replaced. A copy of it is kept so you can restore it.", comment: "Import confirmation message: incoming summary, backup date, current summary"),
            actions: [
                .cancel(),
                AlertState.Action(title: String(localized: "Replace", comment: "Destructive button: replace all data with the backup"), role: .destructive) { [weak self] in
                    self?.replace(with: document, summary: incoming)
                },
            ]
        )
    }

    private func replace(with document: BackupDocument, summary: String) {
        do {
            try backup.replaceAll(with: document)
            hasSnapshot = backup.hasSnapshot
            prepareExport()
            router.popToRoot()
            alert = AlertState(
                title: String(localized: "Data Imported", comment: "Import success title"),
                message: String(localized: "Imported: \(summary).", comment: "Import success message; the argument is like '12 places · 140 items'"),
                actions: [.ok()]
            )
        } catch {
            alert = .error(error)
        }
    }
}
