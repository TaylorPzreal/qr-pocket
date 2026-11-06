# QR Pocket

一个本地运行的 macOS 菜单栏二维码管理工具。支持生成、保存和复用任意多个二维码，以及与 JavaScript `encodeURIComponent` 一致的 URL 编码。

基于 **Rust 启动器 + SwiftUI / AppKit 原生界面**，通过系统 Core Image 生成二维码；没有 WebView，也不需要启动本地服务。

## 功能

- **菜单栏常驻**：点击顶部二维码图标即可搜索、切换、展示已保存的二维码，复制图片或原始内容。关闭管理窗口不会退出应用。
- **二维码库**：每条记录包含名称、原始内容和备注，可新建、编辑、创建副本、删除；支持搜索全部字段。
- **实时生成**：输入链接或文字后自动预览，支持中文和 emoji；可复制图片、复制内容、导出 PNG。
- **URL 编码**：实时展示 `encodeURIComponent` 结果，一键复制，或使用结果创建二维码。切换页面保留输入，不会自动修改原始二维码内容。
- **本地持久化**：不需要账号、网络或服务端，不设保存条目数上限。保存失败保留编辑内容；损坏文件不会被自动覆盖。
- **原生交互**：支持系统深浅色模式，`⌘N` 新建、`⌘S` 保存；切换记录、新建或退出前检查未保存修改，删除前确认。

## 开发运行

需要 macOS 13+、Rust 1.83+，以及包含 Swift 5.9+ 的 Xcode / Command Line Tools。项目没有第三方依赖。

```bash
# 安装 Apple 命令行工具（如尚未安装）
xcode-select --install

# 编译并打开原生应用；首次编译需要一些时间
cargo run
```

每次启动会打开管理窗口，并在菜单栏添加二维码图标，不在 Dock 中常驻。关闭窗口后，可以从菜单栏弹窗点击“打开二维码库”再次打开；右下角设置菜单可以退出应用。

尚未保存的二维码草稿和 URL 编码输入只保留在当前进程中，不会在重启后恢复。二维码必须点击“保存”后才能在菜单栏复用；URL 编码输入不属于二维码草稿的保存提醒范围。

只编译而不打开界面时使用 `cargo build`。启动器也支持以下参数：

```bash
cargo run -- --help
cargo run -- --native-path  # 输出本次构建的原生可执行文件路径
```

## 打包 .app

```bash
bash scripts/bundle-macos.sh
open "dist/QR Pocket.app"
```

将 `dist/QR Pocket.app` 拖到“应用程序”即可使用；生成的应用包含独立的原生可执行文件，不依赖项目目录、Rust 或 Swift 开发工具。默认构建当前 Mac 的架构，不包含通用二进制。

打包使用本机 ad-hoc 签名，**未进行 Developer ID 签名或 Apple 公证**，不等同于可公开分发的正式安装包。跨机器分发需要配置开发者签名和公证。

不要单独分发 `target/release/qrcode-manager`：它是引用构建目录内原生程序的开发启动器。请分发打包后的 `.app`。修改源码后需要重新打包；已运行的进程不会自动更新到新版本。

## 使用示例

1. 点击“新建二维码”，填写名称（例如“测试环境”）、链接和备注，点击保存。
2. 点击菜单栏二维码图标，选择已保存的条目即可展示，方便用手机扫码。
3. 点击侧边栏“URL 编码工具”，输入 `https://example.com/?q=你好`，得到：

```text
https%3A%2F%2Fexample.com%2F%3Fq%3D%E4%BD%A0%E5%A5%BD
```

编码采用 UTF-8，保留 `A-Z a-z 0-9 - _ . ! ~ * ' ( )`，空格编码为 `%20`（不是 `+`）。完整 URL 中的 `:`、`/`、`?`、`&` 等也会编码，因此结果通常用作另一个 URL 的参数值，而非直接访问。对已编码字符串再次编码会将 `%` 转为 `%25`。

## 数据

默认数据文件：

```text
~/Library/Application Support/QR Pocket/library.json
```

记录以版本化 JSON 原子写入，包含 UUID、名称、内容、备注和创建/更新时间。退出应用后可以备份或迁移该文件。内容保持原样，名称会去掉首尾空白。单个二维码内容最多 **2,000 UTF-8 字节**，界面展示实时计数；这是单码容量限制，不是保存条目数限制。

名称和内容不能全为空白，备注可为空。不同记录可以使用相同内容；保存后该记录移到列表顶部。URL 编码结果超过单码容量时仍可复制，但不能直接创建二维码。

数据是本地明文文件，不适合保存密钥等敏感信息。应用使用期间请勿从外部同时编辑该文件或启动多个写入实例。

### 备份与读取失败

1. 退出 QR Pocket，将 `library.json` 复制到安全位置。应用目前不会自动创建备份。
2. 迁移时，在目标 Mac 退出应用后，将完整备份放回相同路径，再重新打开应用。
3. 如果数据损坏或版本不兼容，应用会显示错误并禁用编辑，不会用空库覆盖原文件。可在错误页查看数据位置；先备份，再检查或恢复文件，随后点击“重新加载”。

当前数据格式为 `{ "version": 1, "records": [...] }`。时间字段采用 Foundation 默认的 `Date` 编码，不是 ISO 8601 文本；建议迁移完整文件，不手工拼接记录。

## 验证

```bash
bash scripts/test-native.sh
cargo fmt --check
cargo clippy --all-targets -- -D warnings
cargo test
cargo build --release
bash -n scripts/bundle-macos.sh scripts/test-native.sh
git diff --check
```

原生测试分为两组：

- `CoreTests`：URL 编码、输入验证、草稿修改追踪、增删改查、搜索、重启后恢复、超过一千条记录、损坏/不兼容文件保护、写入失败不修改内存，以及 PNG 实际解码（包含中文和 emoji）、白色静区与最大长度生成。
- `AppTests`：保存与重启恢复、失败时保留草稿、损坏文件禁用编辑、实时预览、切页保留编码输入，以及保存最新修改后创建副本。

定向运行示例：`bash scripts/test-native.sh --filter AppModelTests`。测试使用隔离的临时数据路径，不操作实际二维码库。

`cargo test` 仅验证 Rust 启动器的测试目标；核心功能及界面状态测试请使用 `bash scripts/test-native.sh`。目前没有保存的 GUI 自动化回归测试。

修改 UI 后建议额外人工检查：新建并保存、切换与搜索记录、未保存修改的保存/取消/放弃、创建副本、菜单栏展示与复制、PNG 导出、关闭窗口后重开、URL 编码切页保留、深浅色模式。请勿用真实数据做删除测试。

## 项目结构

```text
.
├── AGENTS.md                  # 编码代理的架构、行为约束和验证指南
├── Cargo.toml / Cargo.lock    # Rust 包与工具链要求
├── build.rs                   # Cargo 构建时编译 Swift 原生应用
├── src/main.rs                # 原生应用开发启动器
├── native/
│   ├── Package.swift          # Swift 包及测试 target
│   ├── Sources/Core/          # 记录、草稿、持久化、URI 编码、二维码渲染
│   ├── Sources/App/           # SwiftUI 界面、AppModel、AppKit 菜单栏与窗口
│   └── Tests/                 # CoreTests 与 AppTests
├── scripts/
│   ├── test-native.sh         # 原生测试入口
│   └── bundle-macos.sh        # 构建并签名独立 .app
└── docs/superpowers/          # 设计与实施记录
```

`build.rs` 将 Swift 原生程序路径注入 Rust 启动器，启动器通过 `exec` 交给原生应用运行。`AppModel` 维护共享 UI 状态；`LibraryStore` 在磁盘写入成功后才更新内存；`QRRenderer` 提供带白色静区的二维码图像与 PNG 数据。

## 常见问题与限制

- **Swift 编译器不可用**：检查 `swift --version` 与 `xcode-select -p`，确认选中的 Xcode / Command Line Tools 包含 Swift 5.9+。
- **非 macOS 或交叉编译失败**：目前仅支持在目标 Mac 上为当前架构本机构建，不提供 Linux、Windows 或 universal binary 构建。
- **受限环境中测试或 release 构建报权限错误**：Core Image、临时文件访问、SwiftPM 缓存或 `dsymutil` 可能被执行沙箱限制。请在具备授权的本地环境运行，不要为了通过测试关闭数据保护逻辑。脚本中的 `--disable-sandbox` 仅作用于 SwiftPM，不解除外层执行环境的限制。
- **扫描复杂二维码困难**：较长内容会增加二维码密度，可尝试导出 PNG 后放大展示或缩短内容。预览与导出始终保持黑码白底。
- **功能边界**：暂不支持二维码图片识别、云同步、批量导入导出、开机自启动配置、自动备份和多进程写入协调。PNG 导出不等于二维码库备份。
