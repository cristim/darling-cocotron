#include <CoreText/CTFontDescriptor.h>
#include <CoreText/CTFontTraits.h>
#include <CoreFoundation/CoreFoundation.h>
#include <stdio.h>

static int failures;
static void check(int condition, const char *name)
{
    if (!condition) {
        fprintf(stderr, "FAIL: %s\n", name);
        failures++;
    }
}

int main(void)
{
    unsigned initial = kCTFontTraitItalic | kCTFontTraitBold;
    double weight = 0.25;
    CFNumberRef symbolic = CFNumberCreate(NULL, kCFNumberIntType, &initial);
    CFNumberRef weightNumber = CFNumberCreate(NULL, kCFNumberDoubleType, &weight);
    const void *traitKeys[] = {kCTFontSymbolicTrait, kCTFontWeightTrait};
    const void *traitValues[] = {symbolic, weightNumber};
    CFDictionaryRef traits = CFDictionaryCreate(NULL, traitKeys, traitValues, 2,
                                                 &kCFTypeDictionaryKeyCallBacks,
                                                 &kCFTypeDictionaryValueCallBacks);
    const void *keys[] = {kCTFontNameAttribute, kCTFontTraitsAttribute};
    const void *values[] = {CFSTR("TestFont"), traits};
    CFDictionaryRef attributes = CFDictionaryCreate(NULL, keys, values, 2,
                                                     &kCFTypeDictionaryKeyCallBacks,
                                                     &kCFTypeDictionaryValueCallBacks);
    CTFontDescriptorRef original = CTFontDescriptorCreateWithAttributes(attributes);
    CTFontDescriptorRef changed = CTFontDescriptorCreateCopyWithSymbolicTraits(
        original, kCTFontTraitMonoSpace, kCTFontTraitBold | kCTFontTraitMonoSpace);

    check(CTFontDescriptorGetSymbolicTraits(original) == initial,
          "original traits remain unchanged");
    check(CTFontDescriptorGetSymbolicTraits(changed) ==
          (kCTFontTraitItalic | kCTFontTraitMonoSpace), "masked trait update");
    CFDictionaryRef changedTraits = CTFontDescriptorCopyAttribute(changed, kCTFontTraitsAttribute);
    check(CFDictionaryContainsKey(changedTraits, kCTFontWeightTrait),
          "numeric weight survives symbolic trait update");
    CFStringRef name = CTFontDescriptorCopyAttribute(changed, kCTFontNameAttribute);
    check(CFEqual(name, CFSTR("TestFont")), "font name survives copy");

    CFRelease(name);
    CFRelease(changedTraits);
    CFRelease(changed);
    CFRelease(original);
    CFRelease(attributes);
    CFRelease(traits);
    CFRelease(weightNumber);
    CFRelease(symbolic);
    puts(failures ? "FAILED" : "ALL PASSED");
    return failures ? 1 : 0;
}
