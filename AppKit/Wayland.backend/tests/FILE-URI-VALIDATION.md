# Host-backed file clipboard and drag transfers

`NSFilenamesPboardType` contains a property-list array of Darwin filenames;
`text/uri-list` contains native URI bytes. These representations now convert in
both clipboard and drag transfers. A native offer exposes both types. Explicit
raw URI data wins over a synthesized list regardless of declaration order.

Incoming file URIs become paths under `/Volumes/SystemRoot`. Outgoing filenames
must already have that exact host-root boundary. Conversion is lexical and does
not access, copy, open or delete files. Guest-only overlay paths are refused:
`__darling_vchroot_expand` resolves in the container mount namespace and does not
prove that the same host pathname names the file. The isolated path probe confirms
that an existing guest lower-layer libSystem maps to a host-missing pathname.
General guest-file export needs a separate design and is not implemented here.

## Conversion invariants

- Convert complete lists atomically. Invalid entries never silently disappear.
- URI bytes use UTF-8 percent encoding and CRLF; spaces, percent signs, hashes,
  Unicode and encoded filename newlines round-trip. Comments and localhost work.
- Reject relative paths, remote authorities, NUL, invalid UTF-8/percent escapes,
  query/fragment syntax, escaped separators and parent traversal components.
- Bound transfers/serialized plists to 16 MiB, records to 4096, and translated
  pathname bytes below 4096. Check bounds before splitting input into objects.
- Incoming DnD caches wire bytes separately from converted data. A malformed file
  list remains available as raw URI data, but a failed requested filename
  conversion prevents MOVE completion even if the receiver returns YES.
- Invalid or nil advertised filename data aborts the outgoing drag snapshot;
  a text fallback cannot authorize MOVE of an undelivered file selection.

## Single-URL and HTML types

`text/uri-list` is also exposed as `NSPasteboardTypeFileURL` (`public.file-url`,
the first file as a guest-visible `file://` URL string, UTF-8) and
`NSPasteboardTypeURL` (`public.url`, the first record; non-file URIs pass through).
`text/html` maps to `NSPasteboardTypeHTML`, `NSHTMLPboardType` and `public.html`.
`text/rtf` is deliberately not mapped: it would change `NSTextView` paste on
Wayland only, and X11 does not do it.

- URL and HTML strings are UTF-8 through `setString:forType:` and `stringForType:`.
- Outgoing, a file URL must name a path under the host root, and
  `NSFilenamesPboardType` takes `text/uri-list` over the URL types in any
  declaration order, so a multi-file drag keeps every file.
- Incoming, the URL types are advertised for every `text/uri-list`. Reading them
  from a list without `file:` records (a browser link) returns nil and does not
  fail the drop; a list that contains a file record still fails atomically.

Modes: `droptest.m` with `FILE_URL_DRAG=1` (also `FILE_URL_ONE`), `LINK_DRAG=1`
(`LINK_WIRE` is the URI list, `LINK_URL` the URL) and `HTML_DRAG=1` (`HTML_WIRE`),
all against `drop-source.c`; `outgoingtest.m` with `URL_DRAG=1` (`URL_ONE`, with
`FILE_WIRE` the expected list) and `FILE_DRAG=1 FILE_URL_FIRST=1 FILE_URL_ONE=...`
against `outgoing-target.c`.

`NSURLPboardType` serialization (its wire format is not documented), arbitrary guest-only files, promised files and
modern pasteboard/session APIs remain follow-ups. Unsupported schemes remain
available through raw URI data but cannot masquerade as local filenames.

## Reproduction

Build `fileurltest.m` (it imports `AppKit/NSPasteboardURIList.m`, shared with X11); it compiles
the exact conversion implementation and tests the valid, invalid and bounded cases.

Use `outgoingtest.m`/`outgoing-target.c` and `droptest.m`/`drop-source.c` on a private
native compositor with `FILE_DRAG=1`. Set `FILE_ONE` and `FILE_TWO` to explicit
host-root paths for two owned scratch files; `FILE_WIRE` is independently encoded
by the host harness. Filenames include space, hash, percent and Japanese text.

Outgoing modes: ordinary conversion; FILE_RAW precedence in both type orders
(REVERSE_RAW); FILE_BAD mixed guest path refusal; FILE_NIL lazy-provider refusal.
The last two advertise MOVE and a text fallback but must emit no begin/end.
Incoming modes: valid list plus repeated converted/raw reads; mixed remote URI
with FILE_BAD, whose receiver deliberately returns YES but must not conclude.
The native source sends data once, proving raw/converted reads share wire cache.

`fileclipboardtest.m` uses keys c/p/q to copy, inspect and exit. Test a roundtrip,
malformed external list, and explicit raw precedence in both declaration orders.
A distinct native-owner comment proves external selection replacement. Use delayed
virtual keyboard injection so keyboard setup completes before the first key.

## Final evidence, 2026-09-16

Backend SHA256:
`c73309647a93cff286f773fee9fe1bc2e2f3dca91a7942340b471ebeda081006`.

- Pure parser: 47/47 checks pass (before the parser moved to AppKit/NSPasteboardURIList.m).
- Native DnD: seven cases pass, including exact URI bytes, cache separation,
  atomic conversion failure and nil-provider refusal.
- Native clipboard: four cases pass, including actual external ownership change.
- All app exits 0, prefix shutdown clean, no owned handles. Private compilation
  and fixed-arity ABI audit pass. Fresh Astra review closed after record/path
  allocation bounds and nil-provider fixes.

Evidence: `darling-gui/privbuild/wayland/files/final-results.json`, `parser-final/`,
`path-probe/`, `run-*/`, `incoming-*/`, `clipboard-*-ready/`. The initial virtual
keyboard readiness failure is preserved and excluded. No user clipboard, Apple
applications, PAC overrides, installed mutations or user prefixes were used.

Format references: [IANA uri-list](https://www.iana.org/assignments/media-types/text/uri-list)
and [RFC 8089 file URIs](https://www.rfc-editor.org/rfc/rfc8089.html).
