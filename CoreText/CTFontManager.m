#import <CoreText/CTFontManager.h>
#import <CoreText/CTFontDescriptor.h>
#import <Foundation/NSString.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSData.h>
#import <Foundation/NSSet.h>
#import <Foundation/NSArray.h>

const CFStringRef kCTFontManagerRegisteredFontsChangedNotification = CFSTR("CTFontManagerFontChangedNotification");

bool CTFontManagerRegisterGraphicsFont(CGFontRef font, CFErrorRef* error)
{
    /* The CGFont (typically from CGFontCreateWithDataProvider, backed by
     * FreeType) is already fully usable; registration is bookkeeping.
     * Report success so clients proceed to CTFont creation. */
    (void)error;
    return (font != NULL);
}

bool CTFontManagerUnregisterGraphicsFont(CGFontRef font, CFErrorRef *error)
{
    (void)error;
    return (font != NULL);
}

CFArrayRef CTFontManagerCopyAvailableFontFamilyNames(void)
{
    CFDictionaryRef empty = CFDictionaryCreate(NULL, NULL, NULL, 0,
        &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CTFontDescriptorRef query = CTFontDescriptorCreateWithAttributes(empty);
    CFArrayRef descriptors = CTFontDescriptorCreateMatchingFontDescriptors(query, NULL);
    NSMutableSet *families = [NSMutableSet set];
    for (NSDictionary *descriptor in (NSArray *)descriptors) {
        id family = [descriptor objectForKey:(id)kCTFontFamilyNameAttribute];
        if (family) [families addObject:family];
    }
    CFRelease(query);
    CFRelease(empty);
    if (descriptors) CFRelease(descriptors);
    return (CFArrayRef)[[[families allObjects] sortedArrayUsingSelector:@selector(compare:)] copy];
}

bool CTFontManagerRegisterFontsForURL(CFURLRef fontURL, CTFontManagerScope scope, CFErrorRef * error)
{
    printf("STUB %s\n", __PRETTY_FUNCTION__);
    return false;
}

/* Private key under which CreateFontDescriptorFromData stashes the raw
 * font bytes for CTFontCreateWithFontDescriptor. */
static CFStringRef DarlingFontDataKey(void) {
    static CFStringRef key = NULL;
    if (!key)
        key = CFSTR("DarlingFontData");
    return key;
}

static uint16_t sfnt_u16(const uint8_t *p) { return (uint16_t)((p[0] << 8) | p[1]); }
static uint32_t sfnt_u32(const uint8_t *p) { return ((uint32_t)p[0] << 24) | ((uint32_t)p[1] << 16) | ((uint32_t)p[2] << 8) | p[3]; }

/* Extract one name-table string (UTF-16BE for Windows platform, MacRoman
 * for Mac platform). Returns a retained CFString or NULL. */
static CFStringRef sfnt_copyName(const uint8_t *data, size_t len,
                                 const uint8_t *storage, size_t storageLen,
                                 uint16_t platform, uint16_t encoding,
                                 uint16_t length, uint16_t offset) {
    const uint8_t *s;
    if (offset >= storageLen || length > storageLen - offset)
        return NULL;
    (void)len;
    s = storage + offset;
    if (platform == 3) {
        /* Windows Unicode BMP: UTF-16BE */
        return CFStringCreateWithBytes(NULL, s, length, kCFStringEncodingUTF16BE, false);
    } else if (platform == 1 && encoding == 0) {
        return CFStringCreateWithBytes(NULL, s, length, kCFStringEncodingMacRoman, false);
    }
    return NULL;
}

CTFontDescriptorRef CTFontManagerCreateFontDescriptorFromData(CFDataRef data) {
    const uint8_t *bytes;
    size_t len, i, j;
    uint16_t numTables, count, stringOffset;
    const uint8_t *nameTab = NULL;
    size_t nameLen = 0;
    CFStringRef psName = NULL, family = NULL, style = NULL;
    NSMutableDictionary *dict;
    CTFontDescriptorRef desc;

    if (!data)
        return NULL;
    len = CFDataGetLength(data);
    bytes = CFDataGetBytePtr(data);
    numTables = sfnt_u16(bytes + 4);
    if (12 + (size_t)numTables * 16 > len)
        return NULL;
    for (i = 0; i < numTables; i++) {
        const uint8_t *rec = bytes + 12 + i * 16;
        if (rec[0] == 'n' && rec[1] == 'a' && rec[2] == 'm' && rec[3] == 'e') {
            uint32_t off = sfnt_u32(rec + 8), tlen = sfnt_u32(rec + 12);
            if (off < len && tlen <= len - off) {
                nameTab = bytes + off;
                nameLen = tlen;
            }
            break;
        }
    }
    if (!nameTab || nameLen < 6)
        return NULL;
    if (sfnt_u16(nameTab) != 0)
        return NULL;
    count = sfnt_u16(nameTab + 2);
    stringOffset = sfnt_u16(nameTab + 4);
    if (6 + (size_t)count * 12 > nameLen || stringOffset > nameLen)
        return NULL;
    /* Pass 1: Windows Unicode (3,1,0x409); pass 2: Mac Roman (1,0,0). */
    for (int pass = 0; pass < 2 && (!psName || !family || !style); pass++) {
        for (j = 0; j < count; j++) {
            const uint8_t *r = nameTab + 6 + j * 12;
            uint16_t plat = sfnt_u16(r), enc = sfnt_u16(r + 2), lang = sfnt_u16(r + 4);
            uint16_t nid = sfnt_u16(r + 6), slen = sfnt_u16(r + 8), soff = sfnt_u16(r + 10);
            CFStringRef *slot = NULL;
            if (pass == 0 && !(plat == 3 && enc == 1 && lang == 0x409))
                continue;
            if (pass == 1 && !(plat == 1 && enc == 0 && lang == 0))
                continue;
            if (nid == 6 && !psName) slot = &psName;
            else if (nid == 1 && !family) slot = &family;
            else if (nid == 2 && !style) slot = &style;
            else if (nid == 4 && !psName) slot = &psName;
            else if (nid == 16 && !family) slot = &family;
            else if (nid == 17 && !style) slot = &style;
            if (slot)
                *slot = sfnt_copyName(bytes, len, nameTab + stringOffset,
                                      nameLen - stringOffset, plat, enc, slen, soff);
        }
    }
    if (!family && psName)
        family = (CFStringRef)[(NSString *)psName retain];
    if (!family) {
        if (psName) CFRelease(psName);
        if (style) CFRelease(style);
        return NULL;
    }

    dict = [NSMutableDictionary dictionary];
    [dict setObject:(NSString *)family forKey:(NSString *)kCTFontFamilyNameAttribute];
    if (style)
        [dict setObject:(NSString *)style forKey:(NSString *)kCTFontStyleNameAttribute];
    if (psName)
        [dict setObject:(NSString *)psName forKey:(NSString *)kCTFontNameAttribute];
    else
        [dict setObject:(NSString *)family forKey:(NSString *)kCTFontNameAttribute];
    /* Stash raw bytes for CTFontCreateWithFontDescriptor. */
    [dict setObject:(NSData *)data forKey:(NSString *)DarlingFontDataKey()];
    desc = CTFontDescriptorCreateWithAttributes((CFDictionaryRef)dict);
    if (psName) CFRelease(psName);
    if (family) CFRelease(family);
    if (style) CFRelease(style);
    return desc;
}
