#import <CoreText/CTFontManager.h>
#import <CoreText/CTFontDescriptor.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSData.h>
#import <Foundation/NSURL.h>

const CFStringRef kCTFontManagerRegisteredFontsChangedNotification = CFSTR("CTFontManagerFontChangedNotification");

// Behaviour unknown (NEEDS-REAL-MAC); does nothing.
void CTFontManagerEnableSystemVisibleFonts(void)
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSLog(@"Stub called: CTFontManagerEnableSystemVisibleFonts (further calls are not logged)");
    });
}

bool CTFontManagerRegisterGraphicsFont(CGFontRef font, CFErrorRef* error)
{
    printf("STUB %s\n", __PRETTY_FUNCTION__);
    return nil;
}

bool CTFontManagerUnregisterGraphicsFont(CGFontRef font, CFErrorRef *error)
{
    printf("STUB %s\n", __PRETTY_FUNCTION__);
    return nil;
}

CFArrayRef CTFontManagerCopyAvailableFontFamilyNames(void)
{
    NSArray *families = [NSArray arrayWithObjects:
        @"Helvetica",
        @"Times",
        @"Courier",
        @"Arial",
        @"Menlo",
        @"Monaco",
        @"Geneva",
        @"Symbol",
        @"Apple Color Emoji",
        nil];
    return (CFArrayRef)[families copy];
}

CFArrayRef CTFontManagerCreateFontDescriptorsFromData(CFDataRef data)
{
    if (!data) return (CFArrayRef)[[NSArray array] retain];
    CGDataProviderRef provider = CGDataProviderCreateWithCFData(data);
    if (!provider) return (CFArrayRef)[[NSArray array] retain];
    CGFontRef cgFont = CGFontCreateWithDataProvider(provider);
    CGDataProviderRelease(provider);
    if (!cgFont) {
        // Font data format could not be parsed by FreeType/Onyx2D
        return (CFArrayRef)[[NSArray array] retain];
    }
    CFStringRef name = CGFontCopyPostScriptName(cgFont);
    CTFontDescriptorRef desc = CTFontDescriptorCreateWithNameAndSize(name, 0);
    if (name) CFRelease(name);
    CGFontRelease(cgFont);
    if (!desc) return (CFArrayRef)[[NSArray array] retain];
    NSArray *result = [NSArray arrayWithObject:(id)desc];
    CFRelease(desc);
    return (CFArrayRef)[result retain];
}

// Synchronously loads font data from fontURL (local file or network URL).
// Network URLs may block if invoked from the main thread.
CFArrayRef CTFontManagerCreateFontDescriptorsFromURL(CFURLRef fontURL)
{
    if (!fontURL) return (CFArrayRef)[[NSArray array] retain];
    NSData *data = [NSData dataWithContentsOfURL:(NSURL *)fontURL];
    if (!data) return (CFArrayRef)[[NSArray array] retain];
    return CTFontManagerCreateFontDescriptorsFromData((CFDataRef)data);
}

bool CTFontManagerRegisterFontsForURL(CFURLRef fontURL, CTFontManagerScope scope, CFErrorRef * error)
{
    printf("STUB %s\n", __PRETTY_FUNCTION__);
    return false;
}
