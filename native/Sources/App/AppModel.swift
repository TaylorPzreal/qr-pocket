import AppKit
import QRPocketCore
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class AppModel: ObservableObject {
    @Published var records: [QRRecord] = []
    @Published var draft = QRDraft()
    @Published var query = ""
    @Published var encoderInput = ""
    @Published var page: Page = .library
    @Published var error: String?
    @Published var notice: String?
    @Published var loadFailed = false
    @Published var preview: NSImage?
    @Published var previewError: String?
    private var store: LibraryStore?
    private var previewTask: Task<Void, Never>?
    private let storeURL: URL
    private let askToSave: () -> NSApplication.ModalResponse

    enum Page { case library, encoder }

    init(url: URL = LibraryRepository.defaultURL, askToSave: @escaping () -> NSApplication.ModalResponse = AppModel.showUnsavedAlert) {
        storeURL = url
        self.askToSave = askToSave
        reload()
    }
    var selected: QRRecord? { records.first { $0.id == draft.id } }
    var isDirty: Bool { draft.hasChanges(from: selected) }
    var filtered: [QRRecord] { store?.search(query) ?? [] }

    func reload() {
        do {
            let loaded = try LibraryStore(url: storeURL)
            store = loaded
            records = loaded.records
            loadFailed = false
            draft = records.first.map { QRDraft(record: $0) } ?? QRDraft()
            refreshPreview()
        } catch {
            loadFailed = true
            self.error = "无法读取本地二维码库：\(error.localizedDescription)\n\(storeURL.path)"
        }
    }

    func confirmDiscard() -> Bool {
        guard isDirty else { return true }
        switch askToSave() {
        case .alertFirstButtonReturn: return save()
        case .alertThirdButtonReturn: return true
        default: return false
        }
    }

    private static func showUnsavedAlert() -> NSApplication.ModalResponse {
        let alert = NSAlert()
        alert.messageText = "保留当前修改？"
        alert.informativeText = "当前二维码有尚未保存的修改。"
        alert.addButton(withTitle: "保存修改")
        alert.addButton(withTitle: "取消")
        alert.addButton(withTitle: "放弃修改")
        return alert.runModal()
    }

    func select(_ record: QRRecord) {
        guard draft.id != record.id, confirmDiscard() else { page = .library; return }
        draft = QRDraft(record: record)
        page = .library
        refreshPreview()
    }

    func newRecord(content: String = "") {
        guard !loadFailed, confirmDiscard() else { return }
        draft = QRDraft()
        draft.content = content
        page = .library
        refreshPreview()
    }

    func duplicate() {
        guard confirmDiscard(), let record = selected else { return }
        draft = QRDraft(duplicating: record)
        refreshPreview()
    }

    @discardableResult
    func save() -> Bool {
        guard let store, !loadFailed else { return false }
        do {
            let record = try store.save(id: draft.id, name: draft.name, content: draft.content, notes: draft.notes)
            records = store.records
            draft = QRDraft(record: record)
            showNotice("已保存到本机")
            return true
        } catch { self.error = error.localizedDescription; return false }
    }

    func deleteSelected() {
        guard let record = selected, let store else { return }
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "删除「\(record.name)」？"
        alert.informativeText = "删除后无法恢复。"
        alert.addButton(withTitle: "取消")
        alert.addButton(withTitle: "删除二维码")
        guard alert.runModal() == .alertSecondButtonReturn else { return }
        do {
            try store.delete(id: record.id)
            records = store.records
            draft = records.first.map { QRDraft(record: $0) } ?? QRDraft()
            refreshPreview()
            showNotice("二维码已删除")
        } catch { self.error = error.localizedDescription }
    }

    func refreshPreview() {
        previewTask?.cancel()
        preview = nil
        previewError = nil
        let content = draft.content
        guard !content.isEmpty else { return }
        previewTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(nanoseconds: 180_000_000)
                guard !Task.isCancelled else { return }
                self?.preview = try QRRenderer.image(for: content)
            } catch is CancellationError { return
            } catch { self?.previewError = error.localizedDescription }
        }
    }

    func copyText(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        showNotice("已复制到剪贴板")
    }

    func copyImage(content: String? = nil) {
        do {
            let data = try QRRenderer.png(for: content ?? draft.content)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setData(data, forType: .png)
            showNotice("已复制二维码图片")
        } catch { self.error = error.localizedDescription }
    }

    func exportPNG() {
        do {
            let data = try QRRenderer.png(for: draft.content)
            let panel = NSSavePanel()
            panel.allowedContentTypes = [.png]
            panel.nameFieldStringValue = (draft.name.isEmpty ? "二维码" : draft.name.replacingOccurrences(of: "/", with: "-")) + ".png"
            guard panel.runModal() == .OK, let url = panel.url else { return }
            try data.write(to: url, options: .atomic)
            showNotice("PNG 已导出")
        } catch { self.error = error.localizedDescription }
    }

    func showNotice(_ text: String) {
        notice = text
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            if self?.notice == text { self?.notice = nil }
        }
    }
}
