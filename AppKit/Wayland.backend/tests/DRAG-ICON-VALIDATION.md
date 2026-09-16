# Native drag icons

`outgoingtest.m` with `DRAG_ICON=1` supplies a 32×24 image containing opaque
magenta, cyan and yellow quadrants and a transparent quadrant. Its image origin
places the icon 20 logical pixels right and 10 down from the pointer. Build the
native GTK destination from `outgoing-target.c`; `FLAT_TARGET=1` makes its content
an opaque RGB(51,51,51), independent of theme text and hover state.

Run on a private compositor with Xwayland disabled. Capture the icon over the
native destination before and after pointer motion. Repeat at integer scale 2
and change the output scale from 1 to 2 during a drag. Verify the same logical
size/offset, every composited pixel, one completion callback, disappearance after
completion/cancellation and clean prefix shutdown. Virtual-pointer normalization
can round the nominal pointer position by one logical pixel.

`ICON_RASTER_OUT` optionally records the pre-Wayland BGRA raster at `ICON_SCALE`.
Compare capture pixels against this raster with premultiplied source-over, rather
than attributing shared NSImage rasterization errors to the backend.

## Implementation

A dedicated drag-icon surface owns immutable shm buffers. Initial attachment
applies the image offset once; later scale changes replace the buffer without
moving the icon. Output enter/leave, scale completion and removal trigger a
coalesced update outside native dispatch. Reentrant image drawing cannot replace
a newer scale update with stale pixels; invalidated icons ignore queued work.
Raster storage is capped at 16 MiB. Failed raster allocation retains the previous
image, or starts without an icon if no image could be created.

The ARGB buffer allocation helper is shared with image cursors. Buffers are never
rewritten while the compositor might use them. No new native ABI entry points.

## Evidence, 2026-09-16

Candidate backend SHA256:
`fac739bb572e40bc220c41091511d4592c80ba61afc81006c3582c834e7cb29d`.

- Installed Onyx baseline: static 2× and live 1×→2× tests compare 9,984 icon pixels,
  zero mismatches, including transparency. Copy delivery succeeds.
- Explicitly reviewed private Onyx coverage fix: another 9,984 pixels match,
  including live scale change followed by cancellation. No installed mutation.
  Onyx SHA256 `fd7d71c1cb69efe0142cba3fbee28ead748adcf854788c146659072c84c53dee`.
- Existing image cursors: baseline/candidate 40×40 logical crops at 1× and 2×
  are byte-identical (24,000 RGB bytes). This verifies the buffer-helper refactor.
- All final runs exit 0, shut down their disposable prefixes and leave no owned
  handles. Private compilation and fixed-arity native ABI audit pass. Fresh Astra
  adversarial review closed after reentrancy fixes and these runtime gates.

Evidence under `darling-gui/privbuild/wayland/icons/`:
`run-accept-flat-two`, `run-accept-flat-dynamic`, `run-accept-onyx-two`,
`run-cancel-onyx-dynamic`, `flat-pixel-results.json`, `onyx-pixel-results.json`,
`cursor-pixel-results.json`, and their original compositor captures/status files.
Earlier GTK text-background comparisons and an early cursor mapping race remain
preserved as harness failures, excluded from the final passing set.

The installed Onyx baseline produces 253 instead of 255 for some opaque image
pixels when scaling. Raw raster evidence isolates this before Wayland; the
separate coverage fix corrects it. This change deliberately preserves the raster.
Multiple physical outputs, allocation failure and adversarial image callbacks
received source review but no runtime success claim. Slide-back and file conversion and modern dragging-session APIs remain follow-ups.
No Apple applications, PAC overrides, installed changes or user prefixes used.

Host-backed filename/URI conversion is covered in FILE-URI-VALIDATION.md; guest-only
export and promises remain unsupported.
