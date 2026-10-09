Build `appkit-pasteboard-read-objects.m` against the rebuilt AppKit and a
Foundation/UniformTypeIdentifiers pair that provides `NSWorkspace` type
conformance. No display connection is needed; the test uses an in-memory
`NSPasteboard` subclass.

It covers `readObjectsForClasses:options:`, `canReadObjectForClasses:options:`
and `canReadItemWithDataConformingToTypes:` for NSString, NSURL (including
`NSPasteboardURLReadingFileURLsOnlyKey`), NSAttributedString,
`NSPasteboardURLReadingContentsConformToTypesKey` (file extension to UTI
conformance), NSImage, RTF with plain-text fallback, and malformed or
unsupported input, which reads as no match instead of raising.

Before the change the first two methods were stubs that printed `STUB` and
returned nil/NO (and `canReadObjectForClasses:options:` did not exist), so the
first positive assertion ("NSString read") fails.
