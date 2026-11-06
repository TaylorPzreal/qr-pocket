import AppKit
import QRPocketCore
import SwiftUI

struct RecordEditor: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .top, spacing: 28) {
                    VStack(alignment: .leading, spacing: 20) {
                        fieldLabel("名称", caption: "为它起个容易找到的名字")
                        TextField("例如：测试环境、个人主页", text: $model.draft.name).textFieldStyle(.roundedBorder).accessibilityLabel("二维码名称")
                        fieldLabel("二维码内容", caption: "链接或任意文字，按原样生成")
                        TextEditor(text: $model.draft.content)
                            .font(.system(size: 12, design: .monospaced)).scrollContentBackground(.hidden)
                            .padding(8).frame(minHeight: 130, maxHeight: 180)
                            .background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 9))
                            .overlay(RoundedRectangle(cornerRadius: 9).stroke(.primary.opacity(0.09)))
                            .accessibilityLabel("二维码内容")
                        Text("\(model.draft.content.utf8.count) / 2,000 UTF-8 字节")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(model.draft.content.utf8.count > 2_000 ? Color.red : Color.secondary)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                    VStack(spacing: 12) {
                        QRPreview(image: model.preview, message: model.previewError).frame(width: 220, height: 220)
                        Label("实时预览", systemImage: "viewfinder").font(.system(size: 11)).foregroundStyle(.secondary)
                        Button { model.copyImage() } label: { Label("复制二维码", systemImage: "doc.on.doc").frame(maxWidth: .infinity) }
                            .buttonStyle(.bordered).disabled(model.preview == nil)
                        HStack {
                            Button("复制内容") { model.copyText(model.draft.content) }.disabled(model.draft.content.isEmpty)
                            Button("导出 PNG") { model.exportPNG() }.disabled(model.preview == nil)
                        }.font(.system(size: 11)).buttonStyle(.borderless)
                    }.frame(width: 220)
                }
                Divider()
                fieldLabel("备注", caption: "使用场景、环境说明，或任何你想记住的信息")
                TextEditor(text: $model.draft.notes)
                    .font(.system(size: 13)).scrollContentBackground(.hidden)
                    .padding(8).frame(height: 90)
                    .background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 9))
                    .overlay(RoundedRectangle(cornerRadius: 9).stroke(.primary.opacity(0.09)))
                    .accessibilityLabel("二维码备注")
                if let record = model.selected {
                    HStack {
                        Text("更新于 \(record.updatedAt.formatted(date: .abbreviated, time: .shortened))").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Button { model.duplicate() } label: { Label("创建副本", systemImage: "plus.square.on.square") }
                        Button(role: .destructive) { model.deleteSelected() } label: { Image(systemName: "trash") }.help("删除二维码").accessibilityLabel("删除二维码")
                    }.buttonStyle(.borderless)
                } else {
                    Label("填写名称与内容后，点击保存即可加入二维码库。", systemImage: "info.circle").font(.caption).foregroundStyle(.secondary)
                }
            }.padding(26)
        }.onChange(of: model.draft.content) { _ in model.refreshPreview() }
    }

    private func fieldLabel(_ title: String, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.system(size: 13, weight: .semibold))
            Text(caption).font(.system(size: 11)).foregroundStyle(.secondary)
        }
    }
}

struct QRPreview: View {
    let image: NSImage?
    var message: String?
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16).fill(.white)
            if let image {
                Image(nsImage: image).interpolation(.none).resizable().scaledToFit().padding(12).accessibilityLabel("生成的二维码")
            } else {
                VStack(spacing: 12) {
                    Image(systemName: message == nil ? "qrcode.viewfinder" : "exclamationmark.triangle").font(.system(size: 44, weight: .ultraLight))
                    Text(message ?? "输入内容\n二维码会出现在这里").font(.system(size: 11)).multilineTextAlignment(.center)
                }.foregroundStyle(Color.black.opacity(0.4)).padding(15)
            }
        }.overlay(RoundedRectangle(cornerRadius: 16).stroke(.black.opacity(0.07)))
            .shadow(color: .black.opacity(0.04), radius: 12, y: 5)
    }
}
