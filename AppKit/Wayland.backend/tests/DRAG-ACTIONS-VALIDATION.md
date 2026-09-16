# COPY and MOVE negotiation

Native action values differ from AppKit: Wayland MOVE is bit 2, while AppKit bit
2 is LINK and MOVE is bit 16. `WaylandDragOperations.h` converts explicitly.
Only COPY/MOVE are advertised. LINK/ASK are not silently changed into MOVE.
Protocol versions before data-device v3 retain COPY-only incoming behavior.

The source snapshots its external and local masks before native startup. A local
destination intersects both permissions. The destination advertises the receiver's
supported intersection, preferring COPY when ambiguous; during prepare/perform it
exposes the single compositor-selected operation. The source reports only a valid
advertised action after both drop and completion. Sources own data removal; this
backend does not delete files or issue legacy DELETE requests.

Native drop freezes the selected action. Previously queued motion retains the
final position without renegotiating. Receiver/action validity is checked again
after prepare callbacks. A drop arriving while a receiver callback has not yet
returned is rejected; stale outer motion results cannot overwrite newer nested
motion. Both guards restore state through Objective-C exceptions.

## Fixtures

Build `outgoingtest.m` as an arm64 AppKit app and `outgoing-target.c` with GTK3.
Use private headless Sway with Xwayland disabled, source at (100,100), destination
at (600,100), and one held virtual pointer from source to destination.

| Source options | Target options | Expected |
| --- | --- | --- |
| SOURCE_MOVE, EXPECT_MOVE | GTK TARGET_MOVE | exact UTF-8 payload, callback MOVE |
| SOURCE_BOTH | GTK COPY | callback COPY |
| SOURCE_MOVE, EXPECT_CANCEL | GTK COPY | no data, callback NONE |
| SOURCE_BOTH, LOCAL_DROP, TARGET_MOVE, EXPECT_MOVE | same app | prepare mask MOVE, original source identity, MOVE |
| SOURCE_MOVE, LOCAL_DROP, LOCAL_REJECT, EXPECT_CANCEL | same app | no data, NONE |
| SOURCE_BOTH, LOCAL_DROP, PREPARE_UNMAP, EXPECT_CANCEL | same app | prepare once, no perform, NONE |
| SOURCE_BOTH, LOCAL_DROP, NESTED_DROP, EXPECT_CANCEL | same app | nested event pumping during updated, no perform, NONE |
| SOURCE_LINK | any | no native start or terminal callback |

For the reverse direction, use `drop-source.c` and `droptest.m` with DROP_MODE
`move-accept`, `accept`, or `move-only` (MOVE source versus COPY destination).
Successful cases require exact Unicode data, cached reads, one prepare/perform/
conclude sequence, and unchanged clipboard. The MOVE source must end with the
MOVE action and no failure. DELETE is hidden from AppKit types and data requests.

## GTK3 deletion boundary

GTK3's native Wayland completion handler already schedules its own DELETE event
on MOVE. In the tested GTK build, the drag ended successfully with MOVE but its
widget-level deletion signal was absent. This evidence proves protocol completion,
not application data deletion. An experimental explicit DELETE request was removed:
it produced a deletion signal but stalled on GTK's NULL selection response, and
could cause duplicate deletion in other implementations. No such workaround ships.
See [GTK Wayland selection completion](https://github.com/GNOME/gtk/blob/gtk-3-24/gdk/wayland/gdkselection-wayland.c)
and [GTK drag selection handling](https://github.com/GNOME/gtk/blob/gtk-3-24/gtk/gtkdnd.c).

## Limits

No runtime claim for multi-receiver nested-motion replacement, every native event
batching order, or old protocol versions; these received adversarial source review.
Core Wayland lacks LINK; ASK needs additional application UI and is not advertised.
Local-only support is covered in LOCAL-DRAG-VALIDATION.md and host-backed
filenames in FILE-URI-VALIDATION.md. Promises and modern dragging sessions remain
follow-ups. Synthetic text fixtures do not establish file move semantics.

## Final evidence, 2026-09-16

Final backend SHA256:
`d248e23fe45bd0c31696ca69bd859d09f6fc30769feefa8c1f51c72ed9077344`.
All eleven cases above pass, each exit0, clean prefix shutdown and no owned handles.
Private compile/link and 35-function fixed-arity ABI audit pass. Fresh Astra review
closed after callback-depth, generation and native-drop freezing corrections.
Evidence: `darling-gui/privbuild/wayland/actions/final-results.json`, the eight
`run-*-standard/` folders and three `incoming-*-standard/` folders. Earlier fixture
mask and experimental DELETE handshake failures remain preserved and excluded.
No installed libraries, Apple applications, PAC overrides or user prefixes used.

Host-backed filename/URI conversion is covered in FILE-URI-VALIDATION.md; guest-only
export and promises remain unsupported.
