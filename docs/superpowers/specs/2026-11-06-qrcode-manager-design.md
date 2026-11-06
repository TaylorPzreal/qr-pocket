# QR Pocket Design

## Scope

A local-only macOS 13+ menu bar utility, implemented on the current branch.
The existing Rust crate remains the build/run entry point. A native SwiftUI and
AppKit application supplies the UI and Core Image supplies QR generation, without
third-party runtime dependencies or a web server.

## User Experience

- A persistent QR menu bar icon opens a compact library popover. Users can also
  open a resizable management window. Closing that window does not quit the app.
- A searchable sidebar lists saved records; the detail pane edits name, exact QR
  content, and multiline notes. A large black-on-white QR preview is scannable.
- New, save, edit, duplicate, delete (with confirmation), copy content, copy QR
  image, and export PNG are supported. New records are blank, not seeded examples.
- Unsaved edits require confirmation before switching records or creating one.
- A URL utility implements JavaScript encodeURIComponent, not encodeURI or form
  encoding. It encodes UTF-8 bytes, preserves A-Z a-z 0-9 - _ . ! ~ * ' ( ), and
  encodes spaces as %20. Encoding is explicit, never silently changes QR content.
- The encoded result can be copied or used as a new QR draft.
- Chinese UI, native keyboard shortcuts, accessible control labels, warm neutral
  surfaces and a restrained teal accent; native light and dark appearances.

## Data And Errors

Each record has a UUID, name, content, notes, creation time and modification time.
An atomic JSON file under Application Support/QR Pocket stores the full library.
There is no arbitrary record-count cap. Name and content are required. Content is
preserved verbatim; a 2,000-byte UTF-8 limit keeps generation bounded and is shown
to users. Oversized QR content is rejected rather than truncated.

Loading corrupt or incompatible data shows an actionable error and prevents
overwriting the original. Failed writes leave the in-memory library and editor
unchanged. A backup is not a substitute for handling read/write errors.
No analytics, network calls, cloud sync or login.

## Boundaries

- Core: Codable records, validation, atomic repository, search, URI encoding.
- QR renderer: Core Image image generation with integer scaling and quiet zone.
- UI state: observable library, editing draft, selection and errors.
- Native shell: menu bar, popover, management window, clipboard and save panel.
- Rust launcher/build: compile the native application and run it; bundle script
  produces a movable .app using the native executable, not an absolute-path shim.

## Verification

Test URI conformance including Chinese, emoji, reserved characters and percent
signs; record creation/edit/delete, Unicode search, persistence round trips,
corrupt files, failed writes, no count cap and QR decode/PNG export. Build debug
and release, format/check Rust, test .app packaging and inspect the live native UI
when desktop permissions allow. Never claim UI verification without evidence.
