// SPDX-License-Identifier: GPL-3.0-only
// Ancillary test tooling, GPL-3.0; the patched cocotron sources keep their own licence.
/* Runs the real CoreText font matching functions against the host's fontconfig and a mock Foundation.
 *
 * tests/coretext-font-matching-host.sh cuts the functions out of CTFontDescriptor.m and CTFontManager.m and points
 * fontconfig at a directory with DejaVu Sans (Book, Bold) and DejaVu Serif (Book) only. Apple documents
 * CTFontDescriptorCreateMatchingFontDescriptors as returning "normalized font descriptors matching the provided
 * descriptor", mandatoryAttributes as keys "which must be identically matched", CTFontDescriptorCreateMatching-
 * FontDescriptor as "the single preferred matching font descriptor" (NULL if none), and
 * CTFontManagerCopyAvailableFontFamilyNames as "an array of visible font family names sorted for UI display". */
#include <objc/runtime.h>
#include <fontconfig/fontconfig.h>
#include <stdarg.h>
#include <stdio.h>
#include <string.h>

typedef unsigned long NSUInteger;
typedef struct __CFString *CFStringRef;
typedef const void *CFTypeRef;
typedef struct __CFArray *CFArrayRef;
typedef struct __CFSet *CFSetRef;
typedef struct __CFDictionary *CFDictionaryRef;
typedef struct __CTFontDescriptor *CTFontDescriptorRef;
typedef struct { unsigned long state; id *itemsPtr; unsigned long *mutationsPtr; unsigned long extra[5]; }
    NSFastEnumerationState;

static FcConfig *O2FontSharedFontConfig(void)
{
    static FcConfig *config;
    if (!config) config = FcInitLoadConfigAndFonts();
    return config;
}

/* Mock Foundation: one root class, strings, URLs, and one list class serving as array, set and dictionary. */
__attribute__((objc_root_class))
@interface NSObject { Class isa; int _refs; }
+ (id)alloc; + (Class)class; - (id)init; - (id)retain; - (void)release; - (id)autorelease;
- (BOOL)isKindOfClass:(Class)c; - (BOOL)isEqual:(id)o;
@end
@implementation NSObject
+ (id)alloc { NSObject *o = class_createInstance(self, 0); o->_refs = 1; return o; }
+ (Class)class { return self; }
- (id)init { return self; }
- (id)retain { _refs++; return self; }
- (void)release { if (--_refs == 0) object_dispose(self); }
- (id)autorelease { return self; } // never drained: the test is short-lived
- (BOOL)isKindOfClass:(Class)c
{
    for (Class k = object_getClass(self); k; k = class_getSuperclass(k)) if (k == c) return YES;
    return NO;
}
- (BOOL)isEqual:(id)o { return o == self; }
@end

@interface NSString : NSObject { @public char *_s; }
+ (id)stringWithUTF8String:(const char *)s; - (const char *)UTF8String; - (NSUInteger)length;
- (BOOL)hasPrefix:(NSString *)p; - (long)compare:(NSString *)o;
@end
@implementation NSString
+ (id)stringWithUTF8String:(const char *)s { NSString *r = [[self alloc] init]; r->_s = strdup(s); return r; }
- (const char *)UTF8String { return _s; }
- (NSUInteger)length { return strlen(_s); }
- (BOOL)hasPrefix:(NSString *)p { return strncmp(_s, [p UTF8String], strlen([p UTF8String])) == 0; }
- (long)compare:(NSString *)o { int c = strcmp(_s, o->_s); return c < 0 ? -1 : c > 0; }
- (BOOL)isEqual:(id)o { return [o isKindOfClass:[NSString class]] && strcmp(_s, ((NSString *)o)->_s) == 0; }
@end
// @"..." literals (the GNUstep 1.x constant string layout).
__attribute__((objc_root_class))
@interface NSConstantString { Class isa; const char *_s; unsigned _len; }
- (const char *)UTF8String;
@end
@implementation NSConstantString
- (const char *)UTF8String { return _s; }
@end
static NSString *S(const char *s) { return [NSString stringWithUTF8String:s]; }

@interface NSURL : NSObject { @public NSString *_path; }
+ (id)fileURLWithPath:(NSString *)p; - (NSString *)path;
@end
@implementation NSURL
+ (id)fileURLWithPath:(NSString *)p { NSURL *u = [[self alloc] init]; u->_path = [p retain]; return u; }
- (NSString *)path { return _path; }
@end

@interface NSArray : NSObject { @public id _k[256], _v[256]; NSUInteger _n; }
+ (id)array; + (id)set; + (id)dictionary; + (id)arrayWithObject:(id)o; + (id)arrayWithObjects:(id)o, ...;
- (NSUInteger)count; - (id)objectAtIndex:(NSUInteger)i; - (void)addObject:(id)o; - (id)copy;
- (id)objectForKey:(id)k; - (void)setObject:(id)v forKey:(id)k; - (NSArray *)allObjects;
- (NSArray *)sortedArrayUsingSelector:(SEL)s;
- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)st objects:(id *)b count:(NSUInteger)n;
@end
@implementation NSArray
+ (id)array { return [[self alloc] init]; }
+ (id)set { return [[self alloc] init]; }
+ (id)dictionary { return [[self alloc] init]; }
+ (id)arrayWithObject:(id)o { NSArray *a = [self array]; [a addObject:o]; return a; }
+ (id)arrayWithObjects:(id)o, ...
{
    NSArray *a = [self array];
    va_list ap;
    va_start(ap, o);
    for (; o; o = va_arg(ap, id)) [a addObject:o];
    va_end(ap);
    return a;
}
- (NSUInteger)count { return _n; }
- (id)objectAtIndex:(NSUInteger)i { return _k[i]; }
- (void)addObject:(id)o { _k[_n++] = [o retain]; }
- (id)copy { NSArray *c = [[object_getClass(self) alloc] init]; for (NSUInteger i = 0; i < _n; i++) { c->_k[i] = _k[i]; c->_v[i] = _v[i]; } c->_n = _n; return c; }
- (id)objectForKey:(id)k { for (NSUInteger i = 0; i < _n; i++) if ([_k[i] isEqual:k]) return _v[i]; return nil; }
- (void)setObject:(id)v forKey:(id)k { _k[_n] = [k retain]; _v[_n++] = [v retain]; }
- (NSArray *)allObjects { return [self copy]; }
- (NSArray *)sortedArrayUsingSelector:(SEL)s
{
    NSArray *c = [self copy];
    for (NSUInteger i = 1; i < c->_n; i++)
        for (NSUInteger j = i; j > 0 && [(NSString *)c->_k[j - 1] compare:c->_k[j]] > 0; j--)
            { id t = c->_k[j]; c->_k[j] = c->_k[j - 1]; c->_k[j - 1] = t; }
    return c;
}
- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)st objects:(id *)b count:(NSUInteger)n
{
    if (st->state) return 0;
    st->state = 1; st->itemsPtr = _k; st->mutationsPtr = &st->extra[0];
    return _n;
}
@end
@interface NSMutableArray : NSArray @end @implementation NSMutableArray @end
@interface NSDictionary : NSArray @end @implementation NSDictionary @end
@interface NSMutableDictionary : NSDictionary @end @implementation NSMutableDictionary @end
@interface NSSet : NSArray @end @implementation NSSet @end
@interface NSMutableSet : NSSet @end
@implementation NSMutableSet
- (void)addObject:(id)o { for (NSUInteger i = 0; i < _n; i++) if ([_k[i] isEqual:o]) return; [super addObject:o]; }
@end

static void CFRelease(CFTypeRef o) { [(id)o release]; }

CFStringRef kCTFontURLAttribute, kCTFontNameAttribute, kCTFontDisplayNameAttribute, kCTFontFamilyNameAttribute,
    kCTFontStyleNameAttribute, kCTFontPostScriptNameAttribute, kCTFontSizeAttribute;

#include FUNCTIONS_INC

static int fails, checks;
#define CK(c, ...) do { checks++; if (!(c)) { fails++; printf("FAIL line %d: ", __LINE__); printf(__VA_ARGS__); printf("\n"); } } while (0)

static NSArray *dict(id k1, id v1, id k2, id v2)
{
    NSArray *d = [NSMutableDictionary dictionary];
    if (k1) [d setObject:v1 forKey:k1];
    if (k2) [d setObject:v2 forKey:k2];
    return d;
}
static NSArray *match(NSArray *query, NSArray *mandatory)
{
    return (NSArray *)CTFontDescriptorCreateMatchingFontDescriptors((CTFontDescriptorRef)query, (CFSetRef)mandatory);
}
static const char *str(NSArray *d, CFStringRef key)
{
    id v = [d objectForKey:(id)key];
    return [v isKindOfClass:[NSString class]] ? [v UTF8String] : "(none)";
}

int main(void)
{
    kCTFontURLAttribute = (CFStringRef)S("NSCTFontFileURLAttribute");
    kCTFontNameAttribute = (CFStringRef)S("NSFontNameAttribute");
    kCTFontDisplayNameAttribute = (CFStringRef)S("NSFontVisibleNameAttribute");
    kCTFontFamilyNameAttribute = (CFStringRef)S("NSFontFamilyAttribute");
    kCTFontStyleNameAttribute = (CFStringRef)S("NSFontFaceAttribute");
    kCTFontPostScriptNameAttribute = (CFStringRef)S("NSFontPostScriptNameAttribute");
    kCTFontSizeAttribute = (CFStringRef)S("NSFontSizeAttribute");
    id family = (id)kCTFontFamilyNameAttribute, style = (id)kCTFontStyleNameAttribute;
    NSString *size = S("13");

    NSArray *sans = match(dict(family, S("DejaVu Sans"), (id)kCTFontSizeAttribute, size), nil);
    CK([sans count] == 2, "family DejaVu Sans matches its two installed faces (got %lu)", [sans count]);
    int bold = 0, book = 0;
    for (NSUInteger i = 0; i < [sans count]; i++) {
        NSArray *d = [sans objectAtIndex:i];
        bold += strcmp(str(d, kCTFontNameAttribute), "DejaVuSans-Bold") == 0;
        book += strcmp(str(d, kCTFontNameAttribute), "DejaVuSans") == 0;
        CK(strcmp(str(d, kCTFontFamilyNameAttribute), "DejaVu Sans") == 0, "each match is family DejaVu Sans (got %s)",
           str(d, kCTFontFamilyNameAttribute));
        NSURL *url = [d objectForKey:(id)kCTFontURLAttribute];
        CK(url && strncmp([[url path] UTF8String], FONT_DIR "/DejaVuSans", strlen(FONT_DIR "/DejaVuSans")) == 0,
           "each match carries the face's file URL");
        CK([d objectForKey:(id)kCTFontSizeAttribute] == size, "the requested point size is kept");
    }
    CK(bold == 1 && book == 1, "the matches are DejaVuSans and DejaVuSans-Bold (PostScript names)");

    CK([match(dict(family, S("No Such Family"), nil, nil), nil) count] == 0,
       "a family that is not installed matches nothing");
    NSArray *serif = match(dict((id)kCTFontNameAttribute, S("DejaVuSerif"), nil, nil), nil);
    CK([serif count] == 1 && strcmp(str([serif objectAtIndex:0], kCTFontFamilyNameAttribute), "DejaVu Serif") == 0,
       "a PostScript name matches that one face");
    NSArray *boldOnly = match(dict(family, S("DejaVu Sans"), style, S("Bold")), nil);
    CK([boldOnly count] == 1 && strcmp(str([boldOnly objectAtIndex:0], kCTFontNameAttribute), "DejaVuSans-Bold") == 0,
       "family plus style Bold matches only the bold face");
    NSArray *keys = [NSSet set];
    [keys addObject:family];
    CK([match(dict(family, S("DejaVu Serif"), nil, nil), keys) count] == 1, "a mandatory family that matches keeps the face");
    NSArray *styleKey = [NSSet set];
    [styleKey addObject:style];
    CK([match(dict(family, S("DejaVu Serif"), nil, nil), styleKey) count] == 0,
       "a mandatory attribute missing from the query matches nothing");

    CK(CTFontDescriptorCreateMatchingFontDescriptor((CTFontDescriptorRef)dict(family, S("No Such Family"), nil, nil), NULL) == NULL,
       "no single match for a family that is not installed");
    NSArray *one = (NSArray *)CTFontDescriptorCreateMatchingFontDescriptor((CTFontDescriptorRef)dict(family, S("DejaVu Serif"), nil, nil), NULL);
    CK(one && strcmp(str(one, kCTFontNameAttribute), "DejaVuSerif") == 0, "the single match is an installed face");

    NSArray *families = (NSArray *)CTFontManagerCopyAvailableFontFamilyNames();
    CK([families count] == 2 && strcmp([[families objectAtIndex:0] UTF8String], "DejaVu Sans") == 0 &&
       strcmp([[families objectAtIndex:1] UTF8String], "DejaVu Serif") == 0,
       "available families are the installed ones, sorted (got %lu, first %s)", [families count],
       [families count] ? [[families objectAtIndex:0] UTF8String] : "-");

#if HAVE_LOCALIZED
    CFStringRef language = (CFStringRef)S("sentinel");
    id value = (id)CTFontDescriptorCopyLocalizedAttribute((CTFontDescriptorRef)dict(family, S("DejaVu Sans"), nil, nil),
                                                         kCTFontFamilyNameAttribute, &language);
    CK(value && strcmp([value UTF8String], "DejaVu Sans") == 0 && language == NULL,
       "CTFontDescriptorCopyLocalizedAttribute gives the value and a NULL language");
#else
    CK(0, "CTFontDescriptorCopyLocalizedAttribute exists");
#endif

    printf("%s: %d checks, %d failed\n", fails ? "FAIL" : "PASS", checks, fails);
    return fails != 0;
}
