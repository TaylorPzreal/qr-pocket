import Foundation

public enum LibraryError: LocalizedError {
    case missingName, missingContent, contentTooLong, missingRecord, invalidStore

    public var errorDescription: String? {
        switch self {
        case .missingName: return "请填写二维码名称。"
        case .missingContent: return "请填写需要生成二维码的内容。"
        case .contentTooLong: return "二维码内容不能超过 2,000 个 UTF-8 字节，请缩短内容后重试。"
        case .missingRecord: return "该二维码已不存在，请重新选择。"
        case .invalidStore: return "数据文件损坏或版本不兼容。原文件未被修改，请备份后检查 library.json。"
        }
    }
}

public struct QRRecord: Codable, Equatable, Identifiable {
    public let id: UUID
    public let name: String
    public let content: String
    public let notes: String
    public let createdAt: Date
    public let updatedAt: Date

    public init(id: UUID = UUID(), name: String, content: String, notes: String = "", createdAt: Date = Date(), updatedAt: Date = Date()) throws {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { throw LibraryError.missingName }
        try Self.validateContent(content)
        self.id = id
        self.name = cleanName
        self.content = content
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public static func validateContent(_ content: String) throws {
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw LibraryError.missingContent }
        guard content.utf8.count <= 2_000 else { throw LibraryError.contentTooLong }
    }
}

public struct LibraryRepository {
    public let url: URL

    private struct Document: Codable {
        let version: Int
        let records: [QRRecord]
    }

    public init(url: URL) { self.url = url }

    public static var defaultURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("QR Pocket", isDirectory: true)
            .appendingPathComponent("library.json")
    }

    public func read() throws -> [QRRecord] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        let data = try Data(contentsOf: url)
        do {
            let document = try JSONDecoder().decode(Document.self, from: data)
            guard document.version == 1,
                  Set(document.records.map(\.id)).count == document.records.count else { throw LibraryError.invalidStore }
            for record in document.records {
                _ = try QRRecord(name: record.name, content: record.content)
            }
            return document.records
        } catch {
            throw LibraryError.invalidStore
        }
    }

    public func write(_ records: [QRRecord]) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(Document(version: 1, records: records))
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: [.atomic, .completeFileProtectionUnlessOpen])
    }
}

public final class LibraryStore {
    public private(set) var records: [QRRecord]
    private let repository: LibraryRepository

    public init(url: URL = LibraryRepository.defaultURL) throws {
        repository = LibraryRepository(url: url)
        records = try repository.read()
    }

    @discardableResult
    public func save(id: UUID? = nil, name: String, content: String, notes: String = "") throws -> QRRecord {
        let existing = records.first { $0.id == id }
        if id != nil && existing == nil { throw LibraryError.missingRecord }
        let record = try QRRecord(id: existing?.id ?? UUID(), name: name, content: content, notes: notes, createdAt: existing?.createdAt ?? Date())
        var next = records.filter { $0.id != record.id }
        next.insert(record, at: 0)
        try repository.write(next)
        records = next
        return record
    }

    public func delete(id: UUID) throws {
        guard records.contains(where: { $0.id == id }) else { throw LibraryError.missingRecord }
        let next = records.filter { $0.id != id }
        try repository.write(next)
        records = next
    }

    public func search(_ query: String) -> [QRRecord] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return records }
        return records.filter { record in
            [record.name, record.content, record.notes].contains { $0.localizedStandardContains(query) }
        }
    }
}
