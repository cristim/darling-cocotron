#import <CoreText/CTFont.h>
#import <CoreText/CTLine.h>
#import <CoreText/CTRun.h>
#import <CoreText/CTParagraphStyle.h>

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

// Private CoreText interfaces that other frameworks use. Declared by their open WebKit SPI header; the semantics are
// CTLineCreateWithAttributedString and CTTypesetterCreateWithAttributedStringAndOptions on the concatenated chunks.
// The callback returns the characters from stringIndex on (NULL when there are none), reports how many it returns and
// their attributes, and the dispose callback (optional) gets the pointer back once its characters were read.
typedef const UniChar *(*CTUniCharProviderCallback)(CFIndex stringIndex, CFIndex *charCount, CFDictionaryRef *attributes, void *refCon);
typedef void (*CTUniCharDisposeCallback)(const UniChar *chars, void *refCon);
CTLineRef CTLineCreateWithUniCharProvider(CTUniCharProviderCallback provider, CTUniCharDisposeCallback dispose, void *refCon);
CFAttributedStringRef KTCoreTextCreateAttributedStringWithProvider(CTUniCharProviderCallback provider, CTUniCharDisposeCallback dispose, void *refCon);
CGSize CTRunGetInitialAdvance(CTRunRef run);

// Which language's line composition rules apply (Japanese kinsoku and the like). Public values are the WebKit SPI's.
typedef CF_ENUM(uint8_t, CTCompositionLanguage) {
    kCTCompositionLanguageUnset,
    kCTCompositionLanguageNone,
    kCTCompositionLanguageJapanese,
    kCTCompositionLanguageSimplifiedChinese,
    kCTCompositionLanguageTraditionalChinese,
};
void CTParagraphStyleSetCompositionLanguage(CTParagraphStyleRef style, CTCompositionLanguage language);

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
