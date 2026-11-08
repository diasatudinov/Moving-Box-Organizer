import Foundation
import SwiftData
@testable import Locibin

/// Fresh in-memory store for each test.
func makeTestContainer() throws -> ModelContainer {
    try ModelContainerFactory.makeInMemory()
}

/// Unique temporary folder for file-system tests; the caller removes it.
func makeTemporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appending(path: "LocibinTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

/// Russian `.lproj` of the app bundle, to check String Catalog translations.
func russianBundle() -> Bundle? {
    Bundle.main.path(forResource: "ru", ofType: "lproj").flatMap(Bundle.init(path:))
}
