# QR Pocket Implementation Plan

**Goal:** Deliver a native local QR library and URL encoder in the macOS menu bar.

**Architecture:** Rust builds and launches a SwiftUI/AppKit executable. Foundation
owns JSON persistence; Core Image renders QR codes. A Swift package exposes the
same core source files to XCTest without third-party dependencies.

**Tech Stack:** Rust 2021, Swift 5 language mode, macOS 13+, SwiftUI, AppKit,
CoreImage, XCTest.

## Global Constraints

- Work on the current branch; preserve the already-staged starter files.
- No web server, network requests, account or arbitrary saved-record count limit.
- Store name, exact content and notes locally; failures must not erase data.
- Match JavaScript encodeURIComponent's UTF-8 behavior exactly.

## Tasks

### 1. Tested Core And Renderer

Files: `native/Package.swift`, `native/Sources/Core/*.swift`,
`native/Tests/CoreTests/*.swift`.

- [x] Write XCTest cases for encoding, validation, CRUD, search, round-trip JSON,
  corrupt-store protection, failed writes and QR decoding.
- [x] Run `swift test --package-path native` with local build/cache paths and
  observe missing-core failures before implementation.
- [x] Implement `URIComponent.encode(_:)`, `QRRecord`, `LibraryRepository`,
  `LibraryStore`, and `QRRenderer.image(for:)` / `png(for:)`.
- [x] Run the tests and confirm all assertions pass against real files/images.

### 2. Native Shell And Editor

Files: `native/Sources/App/*.swift`, `build.rs`, `src/main.rs`.

- [x] Add state coordinating persisted records and unsaved editor drafts.
- [x] Implement library sidebar/detail editor, live preview and URL encoder.
- [x] Add menu bar popover, full management window, clipboard and PNG save panel.
- [x] Build with `cargo build`; fix compiler diagnostics and run core tests.
- [x] Launch and inspect native management window and encoder controls. Full menu
  bar/editor interaction QA is not completed: the app was being used concurrently,
  so automation stopped rather than overwriting the user's input.

### 3. Packaging And Delivery

Files: `scripts/bundle-macos.sh`, `README.md`, `.gitignore`.

- [x] Package native executable and Info.plist into `dist/QR Pocket.app`.
- [x] Document `cargo run`, tests, bundle command, data path and unsigned-app caveat.
- [x] Run Rust formatting, clippy, Swift tests, release build, shell syntax check,
  bundle validation and `git diff --check`.
- [x] Review changes and record any manual verification limitations.

## Review Notes

An independent read-only review found a stale selection captured before the
save/discard confirmation in duplicate creation. A regression test reproduced
the old name/content/notes and the implementation now resolves selection after
confirmation. Rust's documented minimum was aligned to 1.83 for lockfile v4.
Encoder input now lives in observable app state so changing pages preserves it.

No commit is created. The initial staged files are preserved, with new work left
on the current `master` branch as requested.

Final verification: 10 core tests and 6 app-state tests pass; `cargo fmt --check`,
`cargo clippy --all-targets -- -D warnings`, `cargo test`, release packaging,
`codesign --verify --deep --strict`, Info.plist validation, shell syntax checks,
and `git diff --check` pass. The native executable declares macOS 13.0 minimum.
Tests and release tooling required running outside the execution sandbox because
Core Image, protected temporary files, and dsymutil were restricted inside it.
