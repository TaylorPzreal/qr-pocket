import Foundation

public struct QRDraft: Equatable {
    public var id: UUID?
    public var name: String = ""
    public var content: String = ""
    public var notes: String = ""

    public init() {}

    public init(record: QRRecord) {
        id = record.id
        name = record.name
        content = record.content
        notes = record.notes
    }

    public init(duplicating record: QRRecord) {
        name = record.name + " 副本"
        content = record.content
        notes = record.notes
    }

    public func hasChanges(from record: QRRecord?) -> Bool {
        self != (record.map { QRDraft(record: $0) } ?? QRDraft())
    }
}
