Build `appkit-begin-dragging-session.m` against the rebuilt AppKit; no display
connection is needed. A view subclass overrides the legacy
`dragImage:at:offset:event:pasteboard:source:slideBack:` and plays the backend
role (mask query, began, ended), the drag pasteboard is an in-memory fake.
Expected output: `PASS: beginDraggingSessionWithItems`.

Checks: item written to the drag pasteboard; image/location taken from the first
item; session-style source gets `draggingSession:` callbacks in order; a
legacy-only source still gets its own; frameless item drags a 0x0 image;
invalid input, NSPasteboardItem / same-type writers (g21 single-item model) and a
drag that never begins return nil without raising, logging the refusal.
Before the change `beginDraggingSessionWithItems:` did not exist.

`Wayland.backend/tests/outgoingtest.m` `SESSION_API=1` runs the same call on a
headless compositor against the GTK target (see OUTGOING-VALIDATION.md).
