#include <CoreText/CTFontDescriptor.h>
#include <CoreText/CTFont.h>
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

    int type6 = 6, selector0 = 0, selector1 = 1, type35 = 35, selector2 = 2;
    CFNumberRef type6Number = CFNumberCreate(NULL, kCFNumberIntType, &type6);
    CFNumberRef selector0Number = CFNumberCreate(NULL, kCFNumberIntType, &selector0);
    CFNumberRef selector1Number = CFNumberCreate(NULL, kCFNumberIntType, &selector1);
    CFNumberRef type35Number = CFNumberCreate(NULL, kCFNumberIntType, &type35);
    CFNumberRef selector2Number = CFNumberCreate(NULL, kCFNumberIntType, &selector2);
    CTFontDescriptorRef feature0 = CTFontDescriptorCreateCopyWithFeature(changed, type6Number, selector0Number);
    CTFontDescriptorRef feature1 = CTFontDescriptorCreateCopyWithFeature(feature0, type6Number, selector1Number);
    CTFontDescriptorRef feature2 = CTFontDescriptorCreateCopyWithFeature(feature1, type35Number, selector2Number);
    CFArrayRef featureSettings = CTFontDescriptorCopyAttribute(feature2, kCTFontFeatureSettingsAttribute);
    check(CFArrayGetCount(featureSettings) == 2, "feature replaces selector for the same type");
    CFDictionaryRef first = CFArrayGetValueAtIndex(featureSettings, 0);
    check(CFEqual(CFDictionaryGetValue(first, kCTFontFeatureTypeIdentifierKey), type6Number),
          "first feature type preserved");
    check(CFEqual(CFDictionaryGetValue(first, kCTFontFeatureSelectorIdentifierKey), selector1Number),
          "first feature selector replaced");

    int wght = 0x77676874, wdth = 0x77647468;
    CFNumberRef wghtNumber = CFNumberCreate(NULL, kCFNumberIntType, &wght);
    CFNumberRef wdthNumber = CFNumberCreate(NULL, kCFNumberIntType, &wdth);
    CTFontDescriptorRef variation0 = CTFontDescriptorCreateCopyWithVariation(feature2, wghtNumber, 0.25);
    CTFontDescriptorRef variation1 = CTFontDescriptorCreateCopyWithVariation(variation0, wdthNumber, 0.75);
    CTFontDescriptorRef variation2 = CTFontDescriptorCreateCopyWithVariation(variation1, wghtNumber, 0.5);
    CFDictionaryRef variationValues = CTFontDescriptorCopyAttribute(variation2, kCTFontVariationAttribute);
    check(CFDictionaryGetCount(variationValues) == 2, "variation axes preserved");
    double updatedWeight = 0;
    CFNumberGetValue(CFDictionaryGetValue(variationValues, wghtNumber), kCFNumberDoubleType, &updatedWeight);
    check(updatedWeight == 0.5, "variation axis value replaced");
    CFRelease(variationValues);
    CFRelease(variation2);
    CFRelease(variation1);
    CFRelease(variation0);
    CFRelease(wdthNumber);
    CFRelease(wghtNumber);
    CFRelease(featureSettings);
    CFRelease(feature2);
    CFRelease(feature1);
    CFRelease(feature0);
    CFRelease(selector2Number);
    CFRelease(type35Number);
    CFRelease(selector1Number);
    CFRelease(selector0Number);
    CFRelease(type6Number);

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
