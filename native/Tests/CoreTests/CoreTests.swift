import AppKit
import CoreImage
import XCTest
@testable import QRPocketCore

final class CoreTests: XCTestCase {
    func testEncodingMatchesJavaScriptComponents() {
        let fixtures = [
            ("", ""),
            ("AZaz09-_.!~*'()", "AZaz09-_.!~*'()"),
            ("https://example.com/a b?q=你好&x=1#片段", "https%3A%2F%2Fexample.com%2Fa%20b%3Fq%3D%E4%BD%A0%E5%A5%BD%26x%3D1%23%E7%89%87%E6%AE%B5"),
            ("😀 +%/?:@&=,$#[]", "%F0%9F%98%80%20%2B%25%2F%3F%3A%40%26%3D%2C%24%23%5B%5D"),
            ("%20\n\t", "%2520%0A%09")
        ]
        for (input, expected) in fixtures {
            XCTAssertEqual(URIComponent.encode(input), expected)
        }
    }

    func testValidationPreservesExactContentButRequiresANameAndContent() throws {
        let record = try QRRecord(name: "  工作台  ", content: "  https://example.com/你好 \n", notes: "备注\n第二行")
        XCTAssertEqual(record.name, "工作台")
        XCTAssertEqual(record.content, "  https://example.com/你好 \n")
        XCTAssertEqual(record.notes, "备注\n第二行")
        XCTAssertThrowsError(try QRRecord(name: " \n", content: "x"))
        XCTAssertThrowsError(try QRRecord(name: "x", content: " \n"))
        XCTAssertThrowsError(try QRRecord(name: "x", content: String(repeating: "你", count: 667)))
        XCTAssertNoThrow(try QRRecord(name: "x", content: String(repeating: "a", count: 2_000)))
    }

    func testCRUDPersistsAcrossReloadsAndSearchesAllFields() throws {
        let url = temporaryStoreURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = try LibraryStore(url: url)
        let original = try store.save(name: "开发环境", content: "https://EXAMPLE.com", notes: "支付联调")
        XCTAssertEqual(store.search("支付").map(\.id), [original.id])
        XCTAssertEqual(store.search("example").map(\.id), [original.id])
        XCTAssertEqual(store.search("开发").map(\.id), [original.id])
        let edited = try store.save(id: original.id, name: "生产环境", content: "updated", notes: "上线")
        XCTAssertEqual(edited.createdAt, original.createdAt)
        XCTAssertGreaterThanOrEqual(edited.updatedAt, original.updatedAt)
        XCTAssertEqual(store.records.count, 1)
        let loaded = try LibraryStore(url: url)
        XCTAssertEqual(loaded.records, [edited])
        try loaded.delete(id: original.id)
        XCTAssertTrue(try LibraryStore(url: url).records.isEmpty)
    }

    func testNoArbitraryLibraryCountLimitAndDuplicateContentsAllowed() throws {
        let url = temporaryStoreURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let records = try (0..<1_050).map { try QRRecord(name: "记录 \($0)", content: "same") }
        let repository = LibraryRepository(url: url)
        try repository.write(records)
        XCTAssertEqual(try LibraryStore(url: url).records.count, 1_050)
    }

    func testCorruptAndUnsupportedStoresAreNotOverwritten() throws {
        let url = temporaryStoreURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        for text in ["not-json", "{\"version\":99,\"records\":[]}", "{\"version\":1,\"records\":[{}]}"] {
            let bytes = Data(text.utf8)
            try bytes.write(to: url)
            XCTAssertThrowsError(try LibraryStore(url: url))
            XCTAssertEqual(try Data(contentsOf: url), bytes)
        }
    }

    func testFailedWritesDoNotMutateMemory() throws {
        let url = temporaryStoreURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = try LibraryStore(url: url)
        let record = try store.save(name: "keep", content: "value")
        // A directory at the file path makes atomic file replacement fail reliably.
        try FileManager.default.removeItem(at: url)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        XCTAssertThrowsError(try store.save(id: record.id, name: "changed", content: "changed"))
        XCTAssertEqual(store.records, [record])
        XCTAssertThrowsError(try store.delete(id: record.id))
        XCTAssertEqual(store.records, [record])
    }

    func testMissingUpdateCannotSilentlyCreateANewRecord() throws {
        let url = temporaryStoreURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = try LibraryStore(url: url)
        XCTAssertThrowsError(try store.save(id: UUID(), name: "missing", content: "x"))
        XCTAssertTrue(store.records.isEmpty)
    }

    func testDraftTracksUnsavedChangesAndDuplicateIsANewRecord() throws {
        let record = try QRRecord(name: "工作", content: "https://example.com", notes: "备注")
        var draft = QRDraft(record: record)
        XCTAssertFalse(draft.hasChanges(from: record))
        draft.notes = "修改了备注"
        XCTAssertTrue(draft.hasChanges(from: record))
        XCTAssertFalse(QRDraft().hasChanges(from: nil))
        let duplicate = QRDraft(duplicating: record)
        XCTAssertNil(duplicate.id)
        XCTAssertEqual(duplicate.name, "工作 副本")
        XCTAssertEqual(duplicate.content, record.content)
        XCTAssertEqual(duplicate.notes, record.notes)
        XCTAssertTrue(duplicate.hasChanges(from: nil))
    }

    func testMaximumLengthQRCanStillBeRendered() throws {
        XCTAssertNoThrow(try QRRenderer.png(for: String(repeating: "x", count: 2_000)))
        XCTAssertNoThrow(try QRRenderer.png(for: String(repeating: "你", count: 666)))
    }

    func testGeneratedPNGDecodesToExactUnicodeContentAndHasQuietZone() throws {
        let content = "https://example.com/?q=你好&emoji=😀"
        let data = try QRRenderer.png(for: content)
        XCTAssertEqual(Array(data.prefix(8)), [137, 80, 78, 71, 13, 10, 26, 10])
        let image = try XCTUnwrap(CIImage(data: data))
        let detector = try XCTUnwrap(CIDetector(ofType: CIDetectorTypeQRCode, context: CIContext(), options: [CIDetectorAccuracy: CIDetectorAccuracyHigh]))
        let decoded = detector.features(in: image).compactMap { ($0 as? CIQRCodeFeature)?.messageString }
        XCTAssertEqual(decoded, [content])
        let bitmap = try XCTUnwrap(NSBitmapImageRep(data: data))
        XCTAssertGreaterThanOrEqual(bitmap.pixelsWide, 480)
        let corner = try XCTUnwrap(bitmap.colorAt(x: 0, y: 0)?.usingColorSpace(.deviceRGB))
        XCTAssertGreaterThan(corner.redComponent, 0.99)
        XCTAssertGreaterThan(corner.greenComponent, 0.99)
        XCTAssertGreaterThan(corner.blueComponent, 0.99)
        XCTAssertThrowsError(try QRRenderer.png(for: ""))
        XCTAssertThrowsError(try QRRenderer.png(for: String(repeating: "x", count: 2_001)))
    }

    private func temporaryStoreURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("library.json")
    }
}
