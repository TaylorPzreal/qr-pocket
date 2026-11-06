import AppKit
import Foundation
import XCTest
@testable import QRPocket

@MainActor
final class AppModelTests: XCTestCase {
    func testSavingDraftUpdatesLibraryAndRestoresAfterRestart() throws {
        let url = temporaryStoreURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let model = AppModel(url: url)
        XCTAssertFalse(model.loadFailed)
        XCTAssertFalse(model.isDirty)
        model.draft.name = "移动测试"
        model.draft.content = "https://example.com/?q=你好"
        model.draft.notes = "测试备注"
        XCTAssertTrue(model.isDirty)
        XCTAssertTrue(model.save())
        XCTAssertFalse(model.isDirty)
        XCTAssertEqual(model.records.count, 1)
        model.query = "测试备注"
        XCTAssertEqual(model.filtered.count, 1)
        let restarted = AppModel(url: url)
        XCTAssertEqual(restarted.draft, model.draft)
        XCTAssertEqual(restarted.records, model.records)
        model.newRecord()
        XCTAssertNil(model.draft.id)
        XCTAssertTrue(model.draft.content.isEmpty)
    }

    func testFailedSaveKeepsEditedDraftAndPreviousSavedRecord() throws {
        let url = temporaryStoreURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let model = AppModel(url: url)
        model.draft.name = "original"
        model.draft.content = "saved"
        XCTAssertTrue(model.save())
        let original = model.records
        try FileManager.default.removeItem(at: url)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        model.draft.content = "unsaved edit"
        XCTAssertFalse(model.save())
        XCTAssertEqual(model.records, original)
        XCTAssertEqual(model.draft.content, "unsaved edit")
        XCTAssertTrue(model.isDirty)
        XCTAssertNotNil(model.error)
    }

    func testCorruptLoadDisablesCreationAndCannotOverwriteOriginalFile() throws {
        let url = temporaryStoreURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let original = Data("corrupt library".utf8)
        try original.write(to: url)
        let model = AppModel(url: url)
        XCTAssertTrue(model.loadFailed)
        XCTAssertNotNil(model.error)
        model.newRecord(content: "new")
        XCTAssertTrue(model.draft.content.isEmpty)
        XCTAssertFalse(model.save())
        XCTAssertEqual(try Data(contentsOf: url), original)
    }

    func testPreviewUpdatesAfterContentChangeAndRejectsOversizedContent() async throws {
        let url = temporaryStoreURL()
        let model = AppModel(url: url)
        model.draft.content = "https://example.com"
        model.refreshPreview()
        try await Task.sleep(nanoseconds: 500_000_000)
        XCTAssertNotNil(model.preview)
        model.draft.content = String(repeating: "x", count: 2_001)
        model.refreshPreview()
        XCTAssertNil(model.preview)
        try await Task.sleep(nanoseconds: 500_000_000)
        XCTAssertNil(model.preview)
        XCTAssertNotNil(model.previewError)
    }

    func testEncoderInputSurvivesPageSwitchingAndQRCreation() {
        let model = AppModel(url: temporaryStoreURL())
        model.encoderInput = "https://example.com/?q=你好"
        model.page = .encoder
        model.page = .library
        model.page = .encoder
        XCTAssertEqual(model.encoderInput, "https://example.com/?q=你好")
        model.newRecord(content: "https%3A%2F%2Fexample.com")
        XCTAssertEqual(model.encoderInput, "https://example.com/?q=你好")
        XCTAssertEqual(model.draft.content, "https%3A%2F%2Fexample.com")
    }

    func testDuplicateUsesLatestEditsWhenUserSavesInConfirmation() {
        let url = temporaryStoreURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let model = AppModel(url: url, askToSave: { .alertFirstButtonReturn })
        model.draft.name = "original"
        model.draft.content = "old content"
        XCTAssertTrue(model.save())
        model.draft.name = "edited"
        model.draft.content = "new content"
        model.draft.notes = "new notes"
        model.duplicate()
        XCTAssertNil(model.draft.id)
        XCTAssertEqual(model.draft.name, "edited 副本")
        XCTAssertEqual(model.draft.content, "new content")
        XCTAssertEqual(model.draft.notes, "new notes")
        XCTAssertEqual(model.records.first?.content, "new content")
    }

    private func temporaryStoreURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("library.json")
    }
}
