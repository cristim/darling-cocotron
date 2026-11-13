#import <CoreText/CTFont.h>
#import <CoreText/CTLine.h>
#import <CoreText/CTRun.h>

CTLineRef KTCoreTextCreateLineWithRange(CFAttributedStringRef string, CFRange range);
void KTCoreTextFinalizeObject(CFTypeRef object);
CFTypeRef KTCoreTextCreateObject(CFTypeID type, CFDictionaryRef storage);
CFTypeID KTCoreTextRunGetTypeID(void);
CFDictionaryRef KTCoreTextObjectDictionary(CFTypeRef object);

// The attributes of a font descriptor, borrowed from it (valid while the descriptor lives). Every reader of a
// descriptor goes through this. A dictionary, or an object that answers -fontAttributes, is read as it is; a descriptor
// made by another CoreText cannot be read here and stops by class name.
CFDictionaryRef KTCoreTextDescriptorAttributesFrom(CTFontDescriptorRef descriptor, const char *function);
#define KTCoreTextDescriptorAttributes(descriptor) KTCoreTextDescriptorAttributesFrom((descriptor), __func__)
// Not in the public headers: cache frameworks import them.
void *CTFontGetClientObject(CTFontRef font);
void CTFontSetClientObject(CTFontRef font, void *object);
// Makes CF treat objects of a CF type as instances of the named class, when the shared cache defines it.
bool KTCoreTextBridgeType(CFTypeID type, const char *className);
// True for anything that can stand for a descriptor in a cascade list or collection.
bool KTCoreTextIsDescriptor(CFTypeRef object);

extern const CFStringRef kCTFontAttributeName;

extern const CFStringRef KTLineAttributedStringKey;
extern const CFStringRef KTLineRunsKey;
extern const CFStringRef KTLineWidthKey;
extern const CFStringRef KTLineAscentKey;
extern const CFStringRef KTLineDescentKey;
extern const CFStringRef KTLineLeadingKey;

extern const CFStringRef KTRunAttributesKey;
extern const CFStringRef KTRunGlyphsKey;
extern const CFStringRef KTRunPositionsKey;
extern const CFStringRef KTRunAdvancesKey;
extern const CFStringRef KTRunIndicesKey;
extern const CFStringRef KTRunRangeLocationKey;
extern const CFStringRef KTRunRangeLengthKey;
extern const CFStringRef KTRunGlyphCountKey;
extern const CFStringRef KTRunWidthKey;
extern const CFStringRef KTRunAscentKey;
extern const CFStringRef KTRunDescentKey;
extern const CFStringRef KTRunLeadingKey;

CFIndex KTCoreTextDictionaryGetIndex(CFDictionaryRef dictionary,
                                    CFStringRef key);
CGFloat KTCoreTextDictionaryGetFloat(CFDictionaryRef dictionary,
                                     CFStringRef key);
void KTCoreTextDictionarySetIndex(CFMutableDictionaryRef dictionary,
                                  CFStringRef key, CFIndex value);
void KTCoreTextDictionarySetFloat(CFMutableDictionaryRef dictionary,
                                  CFStringRef key, CGFloat value);
