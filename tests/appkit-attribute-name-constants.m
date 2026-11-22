// Attribute names that Mac Catalyst apps bind to AppKit (Books, Clock, FaceTime, FindMy, ...): each must be exported by the
// AppKit image, directly or through its UIFoundation re-export, and hold the string a real Mac holds (mac-probe
// darling_probe_a1.txt, macOS 26.1), which the test pins literally. The copies the UIFoundation stand-in does not export are
// pinned by attribute-name-source-agree.rb.
#import <AppKit/AppKit.h>
#include <dlfcn.h>
#include <stdlib.h>

static void expect(BOOL condition, NSString *message)
{
    if (!condition)
    {
        NSLog(@"FAIL: %@", message);
        exit(1);
    }
}

int main(void)
{
    @autoreleasepool
    {
        static const struct { const char *name; const char *value; } expected[] = {
            { "NSAttachmentAttributeName", "NSAttachment" },
            { "NSBackgroundColorAttributeName", "NSBackgroundColor" },
            { "NSBaselineOffsetAttributeName", "NSBaselineOffset" },
            { "NSCharacterShapeAttributeName", "NSCharacterShape" },
            { "NSCursorAttributeName", "NSCursor" },
            { "NSExpansionAttributeName", "NSExpansion" },
            { "NSFontAttributeName", "NSFont" },
            { "NSForegroundColorAttributeName", "NSColor" },
            { "NSGlyphInfoAttributeName", "NSGlyphInfo" },
            { "NSKernAttributeName", "NSKern" },
            { "NSLigatureAttributeName", "NSLigature" },
            { "NSLinkAttributeName", "NSLink" },
            { "NSMarkedClauseSegmentAttributeName", "NSMarkedClauseSegment" },
            { "NSObliquenessAttributeName", "NSObliqueness" },
            { "NSParagraphAttachmentAttributeName", "NSTextParagraphAnchoredAttachment" },
            { "NSParagraphStyleAttributeName", "NSParagraphStyle" },
            { "NSShadowAttributeName", "NSShadow" },
            { "NSSpellingStateAttributeName", "NSSpellingState" },
            { "NSStrikethroughColorAttributeName", "NSStrikethroughColor" },
            { "NSStrikethroughStyleAttributeName", "NSStrikethrough" },
            { "NSStrokeColorAttributeName", "NSStrokeColor" },
            { "NSStrokeWidthAttributeName", "NSStrokeWidth" },
            { "NSSuperscriptAttributeName", "NSSuperScript" },
            { "NSTextAlternativesAttributeName", "NSTextAlternatives" },
            { "NSTextEncapsulationAttributeName", "NSTextEncapsulation" },
            { "NSToolTipAttributeName", "NSToolTip" },
            { "NSUnderlineColorAttributeName", "NSUnderlineColor" },
            { "NSUnderlineStyleAttributeName", "NSUnderline" },
            { "NSVerticalGlyphFormAttributeName", "CTVerticalForms" },
            { "NSWritingDirectionAttributeName", "NSWritingDirection" },
        };

        Dl_info appKitInfo;
        expect(dladdr((void *)&NSApplicationMain, &appKitInfo) && appKitInfo.dli_fname != NULL, @"AppKit image is found");
        void *appKit = dlopen(appKitInfo.dli_fname, RTLD_LAZY | RTLD_NOLOAD);
        expect(appKit != NULL, @"AppKit handle");

        for (unsigned i = 0; i < sizeof expected / sizeof *expected; i++)
        {
            NSString *name = [NSString stringWithUTF8String:expected[i].name];
            NSString *const *symbol = (NSString *const *)dlsym(appKit, expected[i].name);
            expect(symbol != NULL, [NSString stringWithFormat:@"%@ is exported by AppKit", name]);
            NSString *want = [NSString stringWithUTF8String:expected[i].value];
            expect([*symbol isEqualToString:want], [NSString stringWithFormat:@"%@ is \"%@\", got \"%@\"", name, want, *symbol]);
        }

        // The header declarations are these objects, so AppKit's own text code and apps agree.
        expect([NSFontAttributeName isEqualToString:@"NSFont"], @"header NSFontAttributeName");
        expect([NSForegroundColorAttributeName isEqualToString:@"NSColor"], @"header NSForegroundColorAttributeName");
        NSLog(@"appkit-attribute-name-constants: ok (%u names)", (unsigned)(sizeof expected / sizeof *expected));
    }
    return 0;
}
