Build `appkit-pasteboard-write-objects.m` against the rebuilt AppKit. No display
connection is needed; the test uses an in-memory `NSPasteboard` subclass that
decodes every type except `NSStringPboardType` as UTF-16, like the backends.

It covers `writeObjects:` for NSString, NSURL (web and file, written as UTF-8
`public.url` / `public.file-url` data plus the legacy filenames list),
NSAttributedString (RTF and plain string), NSImage (TIFF) and objects conforming
to `NSPasteboardWriting`, each read back with `readObjectsForClasses:options:`.
Unsupported objects (NSNumber, the stub NSPasteboardItem) and nil input return NO
instead of raising.

Before the change `writeObjects:` did not exist, so the first assertion fails
(unrecognized selector).
