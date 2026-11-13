#import <CoreText/CTFontDescriptor.h>
#import <CoreGraphics/CoreGraphics.h>

CF_IMPLICIT_BRIDGING_ENABLED

typedef CF_ENUM(uint32_t, CTFontManagerScope)
{
    kCTFontManagerScopeNone = 0,
    kCTFontManagerScopeProcess = 1,
    kCTFontManagerScopePersistent = 2,
    kCTFontManagerScopeSession = 3,
    kCTFontManagerScopeUser = 2,
};

CORETEXT_EXPORT const CFStringRef kCTFontManagerRegisteredFontsChangedNotification;

CORETEXT_EXPORT const CFStringRef kCTFontManagerErrorDomain;
CORETEXT_EXPORT const CFStringRef kCTFontManagerErrorFontURLsKey;

typedef CF_ENUM(CFIndex, CTFontManagerError)
{
    kCTFontManagerErrorFileNotFound = 101,
    kCTFontManagerErrorInsufficientPermissions = 102,
    kCTFontManagerErrorUnrecognizedFormat = 103,
    kCTFontManagerErrorInvalidFontData = 104,
    kCTFontManagerErrorAlreadyRegistered = 105,
    kCTFontManagerErrorNotRegistered = 201,
    kCTFontManagerErrorInUse = 202,
    kCTFontManagerErrorSystemRequired = 203,
};

CORETEXT_EXPORT bool CTFontManagerRegisterGraphicsFont(CGFontRef font, CFErrorRef* error);
CORETEXT_EXPORT bool CTFontManagerUnregisterGraphicsFont(CGFontRef font, CFErrorRef *error);

CORETEXT_EXPORT CFArrayRef CTFontManagerCopyAvailableFontFamilyNames(void);

CORETEXT_EXPORT CFArrayRef CTFontManagerCreateFontDescriptorsFromData(CFDataRef data);
CORETEXT_EXPORT CFArrayRef CTFontManagerCreateFontDescriptorsFromURL(CFURLRef fontURL);

CORETEXT_EXPORT bool CTFontManagerRegisterFontsForURL(CFURLRef fontURL, CTFontManagerScope scope, CFErrorRef * error);
CORETEXT_EXPORT bool CTFontManagerUnregisterFontsForURL(CFURLRef fontURL, CTFontManagerScope scope, CFErrorRef * error);

CF_IMPLICIT_BRIDGING_DISABLED
