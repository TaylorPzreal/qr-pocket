import AppKit
import QRPocketCore
import SwiftUI

enum PocketStyle {
    static let accent = Color(red: 0.05, green: 0.46, blue: 0.39)
    static let surface = Color(nsColor: .windowBackgroundColor)
}

struct LibraryView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        HStack(spacing: 0) {
            sidebar.frame(width: 245)
            Divider()
            VStack(spacing: 0) {
                header
                Divider()
                if model.loadFailed {
                    VStack(spacing: 16) {
                        Image(systemName: "externaldrive.badge.exclamationmark").font(.system(size: 40))
                        Text("本地数据暂时无法读取").font(.title2)
                        Text("为保护已有数据，编辑已停用。请检查数据文件后重试。").foregroundStyle(.secondary)
                        Button("重新加载") { model.reload() }
                        Button("查看数据位置") { NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: LibraryRepository.defaultURL.deletingLastPathComponent().path) }
                    }.frame(maxWidth: .infinity, maxHeight: .infinity).padding()
                } else if model.page == .library { RecordEditor(model: model)
                } else { EncoderView(model: model) }
                footer
            }
        }
        .background(PocketStyle.surface).tint(PocketStyle.accent)
        .frame(minWidth: 860, minHeight: 620)
        .alert("操作未完成", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
            Button("知道了") { model.error = nil }
        } message: { Text(model.error ?? "") }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "qrcode").font(.system(size: 29, weight: .medium)).foregroundStyle(PocketStyle.accent)
                VStack(alignment: .leading, spacing: 3) {
                    Text("QR Pocket").font(.system(size: 21, weight: .bold, design: .rounded))
                    Text("让每一次扫码，更简单").font(.system(size: 10)).foregroundStyle(.secondary)
                }
            }.padding(22)
            HStack {
                Label("二维码库", systemImage: "square.grid.2x2")
                Spacer()
                Text("\(model.records.count)").font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary)
            }.font(.system(size: 12, weight: .semibold)).padding(.horizontal, 20)
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("搜索名称、内容、备注", text: $model.query).textFieldStyle(.plain)
                if !model.query.isEmpty {
                    Button { model.query = "" } label: { Image(systemName: "xmark.circle.fill") }.buttonStyle(.plain).accessibilityLabel("清除搜索")
                }
            }.padding(10).background(.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8)).padding(14)
            ScrollView {
                LazyVStack(spacing: 5) {
                    ForEach(model.filtered) { record in
                        Button { model.select(record) } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "qrcode").font(.system(size: 20)).foregroundStyle(PocketStyle.accent)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(record.name).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                                    Text(record.notes.isEmpty ? record.content : record.notes).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                                }
                                Spacer(minLength: 0)
                            }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
                                .background(model.draft.id == record.id && model.page == .library ? PocketStyle.accent.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 9))
                                .contentShape(Rectangle())
                        }.buttonStyle(.plain)
                    }
                    if model.filtered.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: model.query.isEmpty ? "tray" : "magnifyingglass").font(.title2)
                            Text(model.query.isEmpty ? "还没有保存的二维码" : "没有找到匹配的二维码")
                            if model.query.isEmpty { Text("点击下方按钮，创建第一个") }
                        }.font(.caption).foregroundStyle(.secondary).padding(.top, 35)
                    }
                }.padding(.horizontal, 10)
            }
            Button { model.newRecord() } label: { Label("新建二维码", systemImage: "plus").frame(maxWidth: .infinity).padding(.vertical, 5) }
                .buttonStyle(.borderedProminent).keyboardShortcut("n").disabled(model.loadFailed).padding(14)
            Divider().padding(.horizontal, 14)
            Button { model.page = .encoder } label: {
                HStack { Image(systemName: "curlybraces"); Text("URL 编码工具"); Spacer(); Image(systemName: "arrow.up.right").font(.caption) }
                    .padding(12).background(model.page == .encoder ? PocketStyle.accent.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 8))
            }.buttonStyle(.plain).padding(10)
        }.background(.primary.opacity(0.018))
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text(model.page == .library ? "二维码工作台" : "URL 编码工具").font(.system(size: 21, weight: .semibold))
                Text(model.page == .library ? "常用链接与文字，随时扫码取用。" : "安全地将 URL 放进另一个 URL 的参数中。")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            }
            Spacer()
            if model.page == .library && !model.loadFailed {
                if model.isDirty { Text("未保存").font(.caption).foregroundStyle(.orange) }
                Button { model.save() } label: { Label("保存", systemImage: "checkmark") }
                    .buttonStyle(.borderedProminent).keyboardShortcut("s").disabled(!model.isDirty)
            }
        }.padding(.horizontal, 26).padding(.vertical, 22)
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Image(systemName: model.notice == nil ? "lock.shield" : "checkmark.circle.fill")
            Text(model.notice ?? "仅保存在本机 · 无需联网")
            Spacer()
            Text("⌘ N 新建   ⌘ S 保存").foregroundStyle(.tertiary)
        }.font(.system(size: 10)).foregroundStyle(model.notice == nil ? Color.secondary : PocketStyle.accent)
            .padding(.horizontal, 22).padding(.vertical, 12)
    }
}
