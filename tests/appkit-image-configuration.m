#import <Foundation/Foundation.h>
#import <AppKit/NSImage.h>

int main(void) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    NSImage *symbol = [NSImage imageWithSystemSymbolName: @"chevron.backward"
                                accessibilityDescription: @"Back"];
    NSDictionary *hints = @{ NSImageHintSymbolScale: @(NSImageSymbolScaleLarge) };

    NSImage *scaled = [symbol _imageWithConfiguration: hints];
    if (scaled == nil || scaled == symbol) return 1;
    NSImageSymbolConfiguration *expected = [[symbol symbolConfiguration]
            configurationByApplyingConfiguration:
                    [NSImageSymbolConfiguration configurationWithScale: NSImageSymbolScaleLarge]];
    if (![[scaled symbolConfiguration] isEqual: expected]) return 2;
    if ([[scaled symbolConfiguration] isEqual: [symbol symbolConfiguration]]) return 6;
    if ([symbol _imageWithConfiguration: @{}] != symbol) return 3;
    if ([symbol _imageWithConfiguration: nil] != symbol) return 4;

    NSImage *plain = [[[NSImage alloc] initWithSize: NSMakeSize(4, 4)] autorelease];
    if ([plain _imageWithConfiguration: hints] != plain) return 5;

    [pool drain];
    return 0;
}
