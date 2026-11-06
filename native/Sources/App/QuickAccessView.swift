import AppKit
import QRPocketCore
import SwiftUI

struct QuickAccessView: View {
    @ObservedObject var model: AppModel
    let openWindow: () -> Void
    @State private var query = ""
    @State private var selectedID: UUID?
    private var records: [QRRecord] {
        model.records.filter { record in
            query.isEmpty || [record.name, record.content, record.notes].contains { $0.localizedStandardContains(query) }
        }
    }
    private var selected: QRRecord? { records.first { $0.id == selectedID } ?? records.first }
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Label("QR Pocket", systemImage: "qrcode").font(.system(size: 17, weight: .bold, design: .rounded))
                Spacer()
                Button(action: openWindow) { Image(systemName: "arrow.up.left.and.arrow.down.right") }.buttonStyle(.plain).help("打开管理窗口").accessibilityLabel("打开管理窗口")
            }
            TextField("搜索二维码", text: $query).textFieldStyle(.roundedBorder).onChange(of: query) { _ in selectedID = nil }
            if let record = selected {
                QRPreview(image: try? QRRenderer.image(for: record.content)).frame(width: 194, height: 194)
                Text(record.name).font(.headline).lineLimit(1)
                Text(record.notes.isEmpty ? record.content : record.notes).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                HStack {
                    Button("复制图片") { model.copyImage(content: record.content) }
                    Button("复制内容") { model.copyText(record.content) }
                }.buttonStyle(.bordered)
                ScrollView {
                    LazyVStack(spacing: 3) {
                        ForEach(records) { item in
                            Button { selectedID = item.id } label: {
                                HStack {
                                    Image(systemName: "qrcode")
                                    Text(item.name).lineLimit(1)
                                    Spacer()
                                    if item.id == record.id { Image(systemName: "checkmark").foregroundStyle(PocketStyle.accent) }
                                }.font(.system(size: 12)).padding(8).contentShape(Rectangle())
                            }.buttonStyle(.plain)
                        }
                    }
                }.frame(maxHeight: .infinity)
            } else {
                Spacer()
                Image(systemName: "qrcode.viewfinder").font(.system(size: 50, weight: .ultraLight)).foregroundStyle(PocketStyle.accent)
                Text(model.loadFailed ? "本地数据读取失败" : (query.isEmpty ? "你的二维码，随手可用" : "没有匹配的二维码")).font(.headline)
                Text(model.loadFailed ? "请打开管理窗口检查数据文件。" : "在管理窗口中创建并保存二维码。").font(.caption).foregroundStyle(.secondary)
                Spacer()
            }
            Divider()
            HStack {
                Button("打开二维码库", action: openWindow)
                Spacer()
                if let notice = model.notice { Text(notice).font(.system(size: 10)).foregroundStyle(PocketStyle.accent) }
                Menu {
                    Button("新建二维码") { openWindow(); model.newRecord() }.disabled(model.loadFailed)
                    Button("URL 编码工具") { model.page = .encoder; openWindow() }
                    Divider()
                    Button("退出 QR Pocket") { NSApp.terminate(nil) }.keyboardShortcut("q")
                } label: { Image(systemName: "gearshape") }.menuStyle(.borderlessButton).frame(width: 22).accessibilityLabel("更多操作")
            }.font(.caption).buttonStyle(.borderless)
        }.padding(18).frame(width: 360, height: 530).tint(PocketStyle.accent)
    }
}
