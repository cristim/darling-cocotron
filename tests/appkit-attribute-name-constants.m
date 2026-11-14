// Attribute names that Mac Catalyst apps bind to AppKit (Books, Clock, FaceTime, FindMy, ...). The twelve marked in the table
// have to be defined by AppKit itself, not only re-exported from UIFoundation. Every string is the value a real Mac holds
// (mac-probe darling_probe_a1.txt, macOS 26.1). When a separate UIFoundation image is loaded, its copies must agree with
// AppKit's, because the text classes look attributes up under their own copies.
#import <AppKit/AppKit.h>
#include <dlfcn.h>
#include <stdlib.h>
#include <string.h>

static void expect(BOOL condition, NSString *message)
{
    if (!condition)
    {
        NSLog(@"FAIL: %@", message);
        exit(1);
    }
}

static BOOL pathEndsWith(const char *path, const char *tail)
{
    size_t p = strlen(path), t = strlen(tail);
    return p >= t && strcmp(path + p - t, tail) == 0;
}

int main(void)
{
    @autoreleasepool
    {
        // name, the string a real Mac holds (mac-probe darling_probe_a1.txt), 1 when AppKit itself has to define it
        static const struct { const char *name; const char *value; int inAppKit; } expected[] = {
            { "NSAttachmentAttributeName", "NSAttachment", 1 },
            { "NSBackgroundColorAttributeName", "NSBackgroundColor", 1 },
            { "NSBaselineOffsetAttributeName", "NSBaselineOffset", 0 },
            { "NSCharacterShapeAttributeName", "NSCharacterShape", 0 },
            { "NSCursorAttributeName", "NSCursor", 0 },
            { "NSExpansionAttributeName", "NSExpansion", 0 },
            { "NSFontAttributeName", "NSFont", 1 },
            { "NSForegroundColorAttributeName", "NSColor", 1 },
            { "NSGlyphInfoAttributeName", "NSGlyphInfo", 0 },
            { "NSKernAttributeName", "NSKern", 0 },
            { "NSLigatureAttributeName", "NSLigature", 0 },
            { "NSLinkAttributeName", "NSLink", 0 },
            { "NSMarkedClauseSegmentAttributeName", "NSMarkedClauseSegment", 0 },
            { "NSObliquenessAttributeName", "NSObliqueness", 1 },
            { "NSParagraphAttachmentAttributeName", "NSTextParagraphAnchoredAttachment", 1 },
            { "NSParagraphStyleAttributeName", "NSParagraphStyle", 1 },
            { "NSShadowAttributeName", "NSShadow", 0 },
            { "NSSpellingStateAttributeName", "NSSpellingState", 1 },
            { "NSStrikethroughColorAttributeName", "NSStrikethroughColor", 0 },
            { "NSStrikethroughStyleAttributeName", "NSStrikethrough", 0 },
            { "NSStrokeColorAttributeName", "NSStrokeColor", 0 },
            { "NSStrokeWidthAttributeName", "NSStrokeWidth", 0 },
            { "NSSuperscriptAttributeName", "NSSuperScript", 1 },
            { "NSTextAlternativesAttributeName", "NSTextAlternatives", 0 },
            { "NSTextEncapsulationAttributeName", "NSTextEncapsulation", 1 },
            { "NSToolTipAttributeName", "NSToolTip", 0 },
            { "NSUnderlineColorAttributeName", "NSUnderlineColor", 1 },
            { "NSUnderlineStyleAttributeName", "NSUnderline", 1 },
            { "NSVerticalGlyphFormAttributeName", "CTVerticalForms", 0 },
            { "NSWritingDirectionAttributeName", "NSWritingDirection", 0 },
        };

        Dl_info appKitInfo;
        expect(dladdr((void *)&NSApplicationMain, &appKitInfo) && appKitInfo.dli_fname != NULL, @"AppKit image is found");
        void *appKit = dlopen(appKitInfo.dli_fname, RTLD_LAZY | RTLD_NOLOAD);
        expect(appKit != NULL, @"AppKit handle");

        // The image UIFoundation is loaded as, when it is a separate image of this process (the split build); the
        // handle is found through the image that defines NSTextStorage.
        Dl_info textInfo;
        expect(dladdr((void *)[NSTextStorage class], &textInfo) && textInfo.dli_fname != NULL, @"text system image is found");
        void *textImage = pathEndsWith(textInfo.dli_fname, "/AppKit") ? NULL : dlopen(textInfo.dli_fname, RTLD_LAZY | RTLD_NOLOAD);

        for (unsigned i = 0; i < sizeof expected / sizeof *expected; i++)
        {
            NSString *name = [NSString stringWithUTF8String:expected[i].name];
            NSString *const *inAppKit = (NSString *const *)dlsym(appKit, expected[i].name);
            expect(inAppKit != NULL, [NSString stringWithFormat:@"%@ is exported by AppKit", name]);

            if (expected[i].inAppKit)
            {
                Dl_info where;
                expect(dladdr((void *)inAppKit, &where) && where.dli_fname != NULL, [NSString stringWithFormat:@"%@ has an image", name]);
                expect(strcmp(where.dli_fname, appKitInfo.dli_fname) == 0,
                       [NSString stringWithFormat:@"%@ is defined by AppKit itself, not by %s", name, where.dli_fname]);
            }

            NSString *want = [NSString stringWithUTF8String:expected[i].value];
            expect([*inAppKit isEqualToString:want], [NSString stringWithFormat:@"%@ is \"%@\", got \"%@\"", name, want, *inAppKit]);

            if (textImage != NULL)
            {
                NSString *const *inText = (NSString *const *)dlsym(textImage, expected[i].name);
                if (inText != NULL)
                    expect([*inText isEqualToString:want],
                           [NSString stringWithFormat:@"the text system's copy of %@ is \"%@\", AppKit's is \"%@\"", name, *inText, want]);
            }
        }

        // The header declarations are these objects, so AppKit's own text code and apps agree.
        expect([NSFontAttributeName isEqualToString:@"NSFont"], @"header NSFontAttributeName");
        expect([NSForegroundColorAttributeName isEqualToString:@"NSColor"], @"header NSForegroundColorAttributeName");
        NSLog(@"appkit-attribute-name-constants: ok (separate text image: %s)", textImage != NULL ? "yes" : "no");
    }
    return 0;
}
