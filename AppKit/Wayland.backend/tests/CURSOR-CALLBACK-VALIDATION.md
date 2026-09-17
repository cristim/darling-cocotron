# Cursor drawing callbacks

Drawing an application-provided NSImage can select another cursor, hide its
window, or dispatch pointer events. Cursor application now retains its inputs,
rejects obsolete rasterization results, and coalesces a retry after dispatch.
Unmapping the pointer window also clears its enter serial.

## Regression

`cursor-callback.m` is a plain-arm64 AppKit fixture. Run each
`CURSOR_CALLBACK_MODE` in a fresh private prefix with native Wayland and a private
Sway compositor (Xwayland disabled). Move the pointer into the main window,
wait for SELECTED, then change the output from 1280x800 at scale 1 to 2560x1600
at scale 2. Capture actual compositor output including the cursor and collect
WAYLAND_DEBUG=client output. The fixture finishes after seven seconds.

Eight candidate cases passed with exit 0 and clean shutdown:

| Mode | Required evidence after callback |
| --- | --- |
| switch | Exactly one cursor request; red 0, cyan 3072 pixels |
| same | Exactly one cursor request; red 3072, cyan 0 pixels |
| blank | Exactly one NULL-surface cursor request; neither color |
| hide | No cursor request; enter serial zero |
| leave | No cursor request; enter serial zero |
| capability | No cursor request; enter serial zero |
| resize | One nonnull cursor request and buffer attachment to that same surface; neither color |
| release | One cursor request; red 0, cyan 3072; old image destroyed once, after drawing returns |

Every case also requires exactly one triggered rasterization. Leave and
capability cases invoke the real backend handlers synthetically; they do not
claim physical device removal or compositor-generated leave coverage. The
release fixture drains construction autoreleases before the callback to test
last-reference ownership. Other cases retain both cursors.

The parent PR108 backend reproduced the switch failure: red 3072, cyan 0,
despite successful application exit and cleanup. The candidate produced the
expected replacement. This is an observed pixel regression, not only a code
inspection result.

## Recorded validation (2026-09-16)

Private harness and durable results:
`/home/cristi/src/darling-gui/privbuild/wayland/cursor-callbacks/`.
`final-results.json` lists eight candidate runs and the failing baseline.
Candidate backend SHA256:
`f979cea4b87ba0852863ec9c8c9799787c779a79b90210f02d6e00d3fdddf016`.
Compilation, linking, and the 38-entry fixed-arity ABI audit passed.
A fresh Astra reviewer reviewed source, lifecycle handling, and fixture claims.

An earlier release-case attempt never started the fixture: shellspawn startup
timed out. Its original failure status is preserved in
`run-release-candidate-lifetime`; `cleanup-reconciled.json` records subsequent
host verification that its launcher exited and no Darling processes remained.
No privileged signal was sent. The successful fresh run is
`run-release-candidate-reconciled`. Harness cleanup now keeps both runtime locks
until all owned handles exit, including when an ordinary signal is denied.
Earlier input-trigger harness failures are excluded from final results.

This change does not implement fractional scaling. Fresh pointer re-entry,
physical device re-addition, and broad compositor coverage remain separate
validation work.
