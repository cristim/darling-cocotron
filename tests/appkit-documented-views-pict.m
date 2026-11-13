// NSBackgroundExtensionView, NSGlassEffectView and NSPICTImageRep: class, metaclass, superclass, property types and documented behaviour.
#import <AppKit/AppKit.h>
#import <objc/runtime.h>
#include <stdlib.h>
#include <string.h>

static void expect(BOOL condition, NSString *message)
{
    if (!condition)
    {
        NSLog(@"FAIL: %@", message);
        exit(1);
    }
}

static void checkClass(const char *name, const char *superName)
{
    Class cls = objc_getClass(name);
    NSString *label = [NSString stringWithUTF8String:name];
    expect(cls != Nil, [label stringByAppendingString:@" exists"]);
    expect(class_isMetaClass(object_getClass(cls)), [label stringByAppendingString:@" has a metaclass"]);
    expect(class_getSuperclass(cls) == objc_getClass(superName),
           [label stringByAppendingFormat:@" has superclass %s", superName]);
}

static void checkProperty(const char *name, const char *property, const char *type)
{
    objc_property_t p = class_getProperty(objc_getClass(name), property);
    NSString *label = [NSString stringWithFormat:@"%s.%s", name, property];
    expect(p != NULL, [label stringByAppendingString:@" is declared"]);
    char *t = property_copyAttributeValue(p, "T");
    BOOL same = t != NULL && strcmp(t, type) == 0;
    NSString *got = t ? [NSString stringWithUTF8String:t] : @"(none)";
    free(t);
    expect(same, [label stringByAppendingFormat:@" has type %s, got %@", type, got]);
}

int main(void)
{
    @autoreleasepool
    {
        checkClass("NSBackgroundExtensionView", "NSView");
        checkClass("NSGlassEffectView", "NSView");
        checkClass("NSPICTImageRep", "NSImageRep");
        checkProperty("NSBackgroundExtensionView", "contentView", "@\"NSView\"");
        checkProperty("NSBackgroundExtensionView", "automaticallyPlacesContentView", "c");
        checkProperty("NSGlassEffectView", "cornerRadius", "d");
        checkProperty("NSGlassEffectView", "style", "q");
        checkProperty("NSGlassEffectView", "tintColor", "@\"NSColor\"");
        checkProperty("NSPICTImageRep", "PICTRepresentation", "@\"NSData\"");
        checkProperty("NSPICTImageRep", "boundingBox", "{CGRect={CGPoint=dd}{CGSize=dd}}");

        NSBackgroundExtensionView *extension = [[NSBackgroundExtensionView alloc] initWithFrame:NSMakeRect(0, 0, 50, 50)];
        expect(extension.automaticallyPlacesContentView, @"automatic placement defaults to YES");
        NSView *content = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 10, 10)];
        extension.contentView = content;
        expect([content superview] == extension, @"the content view becomes a subview");
        extension.contentView = nil;
        expect([content superview] == nil, @"removing the content view detaches it");

        NSGlassEffectView *glass = [[NSGlassEffectView alloc] initWithFrame:NSMakeRect(0, 0, 50, 50)];
        expect(!glass.effectIsInteractive, @"the glass effect is not interactive by default");
        glass.contentView = content;
        expect([content superview] == glass, @"glass embeds its content view");

        NSData *data = [NSData dataWithBytes:"pict" length:4];
        NSPICTImageRep *rep = [[NSPICTImageRep alloc] initWithData:data];
        expect([rep.PICTRepresentation isEqual:data], @"the PICT data is kept");
        expect([[NSPICTImageRep alloc] initWithData:[NSData data]] == nil, @"empty data is refused");
        printf("PASS: appkit-documented-views-pict\n");
    }
    return 0;
}
