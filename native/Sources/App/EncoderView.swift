import QRPocketCore
import SwiftUI

struct EncoderView: View {
    @ObservedObject var model: AppModel
    private var input: String { model.encoderInput }
    private var output: String { URIComponent.encode(input) }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 12) {
                    Image(systemName: "curlybraces").font(.system(size: 24)).foregroundStyle(PocketStyle.accent)
                    VStack(alignment: .leading, spacing: 5) {
                        Text("encodeURIComponent").font(.system(size: 18, weight: .semibold, design: .monospaced))
                        Text("与 JavaScript 一致 · UTF-8 编码 · 空格转换为 %20").font(.caption).foregroundStyle(.secondary)
                    }
                }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
                    .background(PocketStyle.accent.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
                HStack { Text("原始 URL / 文字").font(.headline); Spacer(); Button("清空") { model.encoderInput = "" }.disabled(input.isEmpty) }
                TextEditor(text: $model.encoderInput).font(.system(size: 13, design: .monospaced)).scrollContentBackground(.hidden)
                    .padding(10).frame(height: 130).background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 9))
                    .overlay(RoundedRectangle(cornerRadius: 9).stroke(.primary.opacity(0.09))).accessibilityLabel("需要编码的 URL")
                Image(systemName: "arrow.down").foregroundStyle(PocketStyle.accent).frame(maxWidth: .infinity)
                HStack { Text("编码结果").font(.headline); Spacer(); Text("\(output.utf8.count) 字节").font(.caption).foregroundStyle(.secondary) }
                ScrollView {
                    Text(output.isEmpty ? "编码后的内容将实时显示在这里" : output)
                        .font(.system(size: 13, design: .monospaced)).textSelection(.enabled)
                        .foregroundStyle(output.isEmpty ? Color.secondary : Color.primary)
                        .frame(maxWidth: .infinity, alignment: .topLeading).padding(14)
                }.frame(height: 130).background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 9))
                HStack {
                    Button { model.copyText(output) } label: { Label("复制编码结果", systemImage: "doc.on.doc") }.buttonStyle(.borderedProminent)
                    Button { model.newRecord(content: output) } label: { Label("用结果创建二维码", systemImage: "qrcode") }
                        .buttonStyle(.bordered).disabled(output.utf8.count > 2_000 || model.loadFailed)
                    Spacer()
                }.disabled(output.isEmpty)
                if output.utf8.count > 2_000 { Text("结果超过二维码容量，仍可复制，但不能直接生成二维码。").font(.caption).foregroundStyle(.orange) }
                Text("提示：完整 URL 的 : / ? & = 等符号也会被编码。结果适合用作 URL 参数值，不是直接访问的地址。再次输入已编码内容时，% 会被编码为 %25。")
                    .font(.caption).foregroundStyle(.secondary).lineSpacing(4)
            }.padding(26)
        }
    }
}
