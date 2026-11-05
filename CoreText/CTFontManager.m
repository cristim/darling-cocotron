#import <CoreText/CTFontManager.h>
#import <CoreText/CTFontDescriptor.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSData.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSSet.h>
#import <Foundation/NSString.h>
#import <Foundation/NSURL.h>

const CFStringRef kCTFontManagerRegisteredFontsChangedNotification = CFSTR("CTFontManagerFontChangedNotification");

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

// The families of the installed faces, as fontconfig lists them, sorted.
// Hidden families (a leading ".") are left out.
CFArrayRef CTFontManagerCopyAvailableFontFamilyNames(void)
{
    CTFontDescriptorRef all = CTFontDescriptorCreateWithAttributes(NULL);
    NSArray *descriptors = (NSArray *)CTFontDescriptorCreateMatchingFontDescriptors(all, NULL);
    NSMutableSet *families = [NSMutableSet set];
    for (NSDictionary *descriptor in descriptors) {
        NSString *family = [descriptor objectForKey:(id)kCTFontFamilyNameAttribute];
        if ([family length] > 0 && ![family hasPrefix:@"."])
            [families addObject:family];
    }
    [descriptors release];
    CFRelease(all);
    return (CFArrayRef)[[[families allObjects] sortedArrayUsingSelector:@selector(compare:)] copy];
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
