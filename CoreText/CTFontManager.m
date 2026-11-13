#import <CoreText/CTFontManager.h>
#import <CoreText/CTFontDescriptor.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSData.h>
#import <Foundation/NSURL.h>

const CFStringRef kCTFontManagerRegisteredFontsChangedNotification = CFSTR("CTFontManagerFontChangedNotification");

// GUESS: the error domain and the user-info key values are not public; the names are.
const CFStringRef kCTFontManagerErrorDomain = CFSTR("com.apple.CoreText.CTFontManagerErrorDomain");
const CFStringRef kCTFontManagerErrorFontURLsKey = CFSTR("CTFontManagerErrorFontURLsKey");

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

// CTFontManagerRegisterFontsForURL registers nothing here, so no font URL is ever registered and
// unregistering one fails with the documented "not registered" error carrying the URL.
bool CTFontManagerUnregisterFontsForURL(CFURLRef fontURL, CTFontManagerScope scope, CFErrorRef * error)
{
    if (error != NULL) {
        const void *urlValues[] = {fontURL};
        CFArrayRef urls = CFArrayCreate(NULL, urlValues, fontURL != NULL ? 1 : 0, &kCFTypeArrayCallBacks);
        const void *keys[] = {kCTFontManagerErrorFontURLsKey};
        const void *values[] = {urls};
        CFDictionaryRef info = CFDictionaryCreate(NULL, keys, values, 1, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
        *error = CFErrorCreate(NULL, kCTFontManagerErrorDomain, kCTFontManagerErrorNotRegistered, info);
        CFRelease(info);
        CFRelease(urls);
    }
    return false;
}
