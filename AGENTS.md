# Project Guide

## 项目定位

QR Pocket 是一个 macOS 13+ 本地菜单栏二维码管理工具，不是 Web 应用。
用户文档见 `README.md`；设计与实施记录位于 `docs/superpowers/`。
文档与实现不一致时，以当前代码为准，并在修改功能时同步更新文档。

核心功能：

- 菜单栏快速搜索、选择、展示已保存二维码，复制图片和原始内容。
- 管理窗口维护名称、内容、备注，支持新建、编辑、副本、删除和 PNG 导出。
- URL 工具提供 JavaScript `encodeURIComponent` 语义，可用编码结果创建二维码。
- 使用本地版本化 JSON 持久化，无账号、网络、服务端或第三方运行时依赖。

## 技术栈与入口

- Rust 2021，最低 Rust/Cargo 1.83（`Cargo.lock` 使用 v4）。
- Swift tools 5.9+，SwiftUI、AppKit、Foundation、Core Image；最低 macOS 13。
- `cargo run` 是开发入口；`build.rs` 根据 Cargo profile 调用 Swift Package Manager。
- 不支持跨系统、跨架构交叉编译；在目标 Mac 上构建。
- 当前不需要 Node.js、npm、WebView、数据库或第三方二维码库。

## 代码地图

| 路径 | 职责 |
| --- | --- |
| `Cargo.toml` / `Cargo.lock` | Rust 包配置和工具链兼容性 |
| `build.rs` | 编译 Swift 包，定位原生可执行文件并注入启动器 |
| `src/main.rs` | 通过 `exec` 启动原生程序；支持 `--help`、`--native-path` |
| `native/Package.swift` | `QRPocketCore`、`QRPocket`、`CoreTests`、`AppTests` target |
| `native/Sources/Core/Library.swift` | 记录验证、JSON 仓库、CRUD 与搜索 |
| `native/Sources/Core/QRDraft.swift` | 编辑草稿、变更判断和副本初始化 |
| `native/Sources/Core/URIComponent.swift` | UTF-8 百分号编码 |
| `native/Sources/Core/QRRenderer.swift` | 二维码图像、静区和 PNG 数据 |
| `native/Sources/App/AppModel.swift` | 主线程可观察状态、草稿保护、预览、剪贴板、导出 |
| `native/Sources/App/QRPocketApp.swift` | App 生命周期、状态栏图标、popover 和管理窗口 |
| `native/Sources/App/LibraryView.swift` | 管理窗口框架、侧栏、搜索、错误与通知 |
| `native/Sources/App/RecordEditor.swift` | 记录编辑表单与共享二维码预览组件 |
| `native/Sources/App/EncoderView.swift` | URL 编码页 |
| `native/Sources/App/QuickAccessView.swift` | 菜单栏快速访问页 |
| `native/Tests/CoreTests/` | 编码、数据、草稿与二维码真实解码测试 |
| `native/Tests/AppTests/` | 应用状态与保存/预览等集成测试 |
| `scripts/test-native.sh` | 统一原生测试命令与构建缓存位置 |
| `scripts/bundle-macos.sh` | release 构建、Info.plist、独立 `.app` 与 ad-hoc 签名 |

## 必须保持的行为

### 数据安全

- 默认文件为 `~/Library/Application Support/QR Pocket/library.json`，文档版本为 `1`。
- `QRRecord` 包含 UUID、名称、原始内容、备注及创建/更新时间。
- 名称去掉首尾空白后不能为空；内容不能全为空白，但存储与生成必须保留原始内容，不自动 trim、编码或规范化 URL。
- 内容最多 2,000 UTF-8 **字节**，不是字符数。条目数没有业务上限，允许重复内容。
- `LibraryStore` 先将候选结果原子写入磁盘，成功后才更新内存。不要颠倒顺序。
- 读取失败、格式损坏、未知版本和重复 UUID 不能当作空库并写回；应用应禁用写入并保留原文件。
- 更新不存在的 UUID 必须报错，不能隐式新增。编辑保留 UUID/创建时间，更新后移到列表首位。
- 测试只能使用隔离的临时 URL，不能读写用户真实二维码库。
- 当前没有文件监控、并发实例协调或自动备份；不要声称支持这些能力。

### 草稿与界面

- 菜单栏只使用已保存记录，不能将未保存草稿冒充保存结果。
- 切换记录、新建、创建副本或退出时，通过保存/取消/放弃流程保护二维码草稿；写入失败必须保留草稿。
- 保存确认可能改变当前记录，后续操作必须读取最新状态，尤其是“保存后创建副本”。
- 关闭管理窗口不退出程序，也不丢弃当前进程中的草稿。
- URL 编码输入属于 `AppModel`，切页后保留，但不持久化到磁盘。
- UI 状态由 `@MainActor AppModel` 协调；不要让 SwiftUI 视图另行写数据文件。
- 保留中文文案、系统深浅色适配及可访问性标签。二维码始终黑码白底，不能随深色主题反转。
- 实时预览采用可取消的延迟任务；改动时检查旧预览不会覆盖新内容。

### 编码与渲染

- `URIComponent.encode` 按 UTF-8 字节编码，保留 `A-Z a-z 0-9 - _ . ! ~ * ' ( )`，使用大写十六进制。
- 空格为 `%20`，不是 `+`；完整 URL 的分隔符也要编码；已有 `%` 再次编码为 `%25`。
- 不得替换为 `encodeURI`、表单编码或只编码 query 的逻辑。编码必须显式触发二维码草稿创建，不改变已有内容。
- Core Image 生成二维码，纠错等级为 `M`，四周保留至少四个模块的白色静区，使用整数倍缩放和无插值显示。
- 渲染变更必须验证 PNG 能被实际解码，不能只检查“生成了一张图片”。

## 常用命令

在项目根目录执行：

```bash
cargo run                                      # 开发运行，会打开 GUI
cargo build                                    # 仅编译
bash scripts/test-native.sh                     # 核心和应用状态测试
bash scripts/test-native.sh --filter CoreTests  # 定向测试
cargo fmt --check
cargo clippy --all-targets -- -D warnings
cargo test
bash -n scripts/bundle-macos.sh scripts/test-native.sh
bash scripts/bundle-macos.sh                    # 构建并签名 dist/QR Pocket.app
codesign --verify --deep --strict "dist/QR Pocket.app"
git diff --check
```

`cargo test` 当前没有 Rust 测试用例，不能替代原生测试。Rust 构建仍会编译 Swift 应用。
不要将状态集成测试称为 GUI E2E 测试；当前没有保存的 GUI 自动化回归用例。
沙箱可能阻止 Core Image、临时文件访问或 `dsymutil`；遇到权限错误应按执行环境请求授权，不要删减测试或改变产品数据保护逻辑来绕过。

## 修改与交付

- 优先保持现有 Core / App / 构建脚本边界，避免为了局部修改引入框架或无关重构。
- 行为修改先补可复现的失败测试，再实现；覆盖 Unicode、字节边界、错误路径和草稿生命周期。
- UI 修改还需人工验证菜单栏、关闭后重开窗口、保存提示和深浅色布局；不能只以测试通过宣称视觉验证完成。
- 不覆盖正在使用应用的用户输入，不在真实数据中创建或删除 QA 记录；需要时用临时仓库做状态测试。
- 构建脚本修改需重新验证 release 打包；复制的是原生可执行文件，不能把嵌有绝对路径的 Rust 开发启动器当作可分发应用。
- `.app` 当前仅 ad-hoc 签名，无 Developer ID 签名、公证或 universal binary；版本变更时同步检查 Cargo 与脚本内 Info.plist。
- `target/`、`.build-cache/`、`dist/`、`native/.build/`、`native/.swiftpm/` 都是忽略的生成目录，不提交构建产物。
- 保留用户已有工作区与暂存区修改，未经请求不切换分支、不提交、不重置文件。
- 交付时列出实际执行的检查以及未完成的人工验证；仅文档变更可做内容、路径和 diff 检查，无需重跑全部 GUI/构建流程。
