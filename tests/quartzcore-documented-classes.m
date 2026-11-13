// CAEAGLLayer, CATiledLayer, CAEDRMetadata and CAMetalDisplayLink: class, metaclass, superclass, property types and documented behaviour.
#import <QuartzCore/QuartzCore.h>
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
        checkClass("CAEAGLLayer", "CALayer");
        checkClass("CATiledLayer", "CALayer");
        checkClass("CAEDRMetadata", "NSObject");
        checkClass("CAMetalDisplayLink", "NSObject");
        checkProperty("CAEAGLLayer", "drawableProperties", "@\"NSDictionary\"");
        checkProperty("CAEAGLLayer", "presentsWithTransaction", @encode(BOOL));
        checkProperty("CATiledLayer", "levelsOfDetail", "Q");
        checkProperty("CATiledLayer", "tileSize", "{CGSize=dd}");
        checkProperty("CAMetalDisplayLink", "preferredFrameLatency", "f");
        checkProperty("CAMetalDisplayLink", "paused", @encode(BOOL));

        CATiledLayer *tiled = [CATiledLayer layer];
        expect(tiled.levelsOfDetail == 1 && tiled.levelsOfDetailBias == 0, @"documented level defaults");
        expect(tiled.tileSize.width == 256.0 && tiled.tileSize.height == 256.0, @"documented tile size");
        expect([CATiledLayer fadeDuration] == 0.25, @"documented fade duration");
        tiled.levelsOfDetailBias = 2;
        expect(tiled.levelsOfDetailBias == 2, @"bias is stored");

        CAEAGLLayer *eagl = [CAEAGLLayer layer];
        eagl.drawableProperties = @{ @"k" : @1 };
        expect([eagl.drawableProperties count] == 1 && !eagl.presentsWithTransaction, @"EAGL layer properties");

        expect([CAEDRMetadata HLGMetadata] != nil, @"HLG metadata exists");
        expect([CAEDRMetadata HDR10MetadataWithMinLuminance:0.1 maxLuminance:1000 opticalOutputScale:100] != nil,
               @"HDR10 metadata exists");

        CAMetalDisplayLink *link = [[CAMetalDisplayLink alloc] initWithMetalLayer:[CAMetalLayer layer]];
        expect(!link.paused, @"the link is not paused");
        link.paused = YES;
        [link addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        [link invalidate];
        expect(link.paused, @"pause is stored");
        printf("PASS: quartzcore documented classes\n");
    }
    return 0;
}
