#import <CoreVideo/CoreVideo.h>
#import <IOSurface/IOSurface.h>
#import <Onyx2D/O2Surface.h>
#import <OpenGL/OpenGL.h>
#import <QuartzCore/CAAnimation.h>
#import <QuartzCore/CAMediaTimingFunction.h>
#import <QuartzCore/CARenderer.h>
#import "CALayerInternal.h"
#include <stdlib.h>

NSString *const kCARendererColorSpace = @"kCARendererColorSpace";

@implementation CARenderer

- (CGRect) bounds {
    return _bounds;
}

- (void) setBounds: (CGRect) value {
    _bounds = value;
}

@synthesize layer = _rootLayer;

- initWithCGLContext: (void *) cglContext options: (NSDictionary *) options {
    _cglContext = cglContext;
    _bounds = CGRectZero;
    _rootLayer = nil;
    return self;
}

+ (CARenderer *) rendererWithCGLContext: (void *) cglContext
                                options: (NSDictionary *) options
{
    return [[[self alloc] initWithCGLContext: cglContext
                                     options: options] autorelease];
}

static void startAnimationsInLayer(CALayer *layer, CFTimeInterval currentTime) {
    NSArray *keys = [layer animationKeys];

    for (NSString *key in keys) {
        CAAnimation *check = [layer animationForKey: key];

        if ([check beginTime] == 0.0)
            [check setBeginTime: currentTime];
        if (currentTime > [check beginTime] + [check duration]) {
            [layer removeAnimationForKey: key];
        }
    }

    for (CALayer *child in layer.sublayers)
        startAnimationsInLayer(child, currentTime);
}

- (void) beginFrameAtTime: (CFTimeInterval) currentTime
                timeStamp: (CVTimeStamp *) timeStamp
{
    startAnimationsInLayer(_rootLayer, currentTime);
}

static inline CGFloat cubed(CGFloat value) {
    return value * value * value;
}

static inline CGFloat squared(CGFloat value) {
    return value * value;
}

static CGFloat applyMediaTimingFunction(CAMediaTimingFunction *function,
                                        CGFloat t)
{
    CGFloat result;
    CGFloat cp1[2];
    CGFloat cp2[2];

    [function getControlPointAtIndex: 1 values: cp1];
    [function getControlPointAtIndex: 2 values: cp2];

    double x = cubed(1.0 - t) * 0.0 + 3 * squared(1 - t) * t * cp1[0] +
               3 * (1 - t) * squared(t) * cp2[0] + cubed(t) * 1.0;
    double y = cubed(1.0 - t) * 0.0 + 3 * squared(1 - t) * t * cp1[1] +
               3 * (1 - t) * squared(t) * cp2[1] + cubed(t) * 1.0;

    // this is wrong
    return y;
}

static CGFloat mediaTimingScale(CAAnimation *animation,
                                CFTimeInterval currentTime)
{
    CFTimeInterval begin = [animation beginTime];
    CFTimeInterval duration = [animation duration];
    CFTimeInterval delta = currentTime - begin;
    double zeroToOne = delta / duration;
    CAMediaTimingFunction *function = [animation timingFunction];

    if (function == nil)
        function = [CAMediaTimingFunction
                functionWithName: kCAMediaTimingFunctionDefault];

    return applyMediaTimingFunction(function, zeroToOne);
}

static CGFloat interpolateFloatInLayerKey(CALayer *layer, NSString *key,
                                          CFTimeInterval currentTime)
{
    CAAnimation *animation = [layer animationForKey: key];

    if (animation == nil)
        return [[layer valueForKey: key] floatValue];

    if ([animation isKindOfClass: [CABasicAnimation class]]) {
        CABasicAnimation *basic = (CABasicAnimation *) animation;

        id fromValue = [basic fromValue];
        id toValue = [basic toValue];

        if (toValue == nil)
            toValue = [layer valueForKey: key];

        CGFloat fromFloat = [fromValue floatValue];
        CGFloat toFloat = [toValue floatValue];

        CGFloat resultFloat;
        double timingScale = mediaTimingScale(animation, currentTime);

        resultFloat = fromFloat + (toFloat - fromFloat) * timingScale;

        return resultFloat;
    }

    return 0;
}

static CGPoint interpolatePointInLayerKey(CALayer *layer, NSString *key,
                                          CFTimeInterval currentTime)
{
    CAAnimation *animation = [layer animationForKey: key];

    if (animation == nil)
        return [[layer valueForKey: key] pointValue];

    if ([animation isKindOfClass: [CABasicAnimation class]]) {
        CABasicAnimation *basic = (CABasicAnimation *) animation;

        id fromValue = [basic fromValue];
        id toValue = [basic toValue];

        if (toValue == nil)
            toValue = [layer valueForKey: key];

        CGPoint fromPoint = [fromValue pointValue];
        CGPoint toPoint = [toValue pointValue];

        CGPoint resultPoint;
        double timingScale = mediaTimingScale(animation, currentTime);

        resultPoint.x = fromPoint.x + (toPoint.x - fromPoint.x) * timingScale;
        resultPoint.y = fromPoint.y + (toPoint.y - fromPoint.y) * timingScale;

        return resultPoint;
    }

    return CGPointMake(0, 0);
}

static CGRect interpolateRectInLayerKey(CALayer *layer, NSString *key,
                                        CFTimeInterval currentTime)
{
    CAAnimation *animation = [layer animationForKey: key];

    if (animation == nil) {
        return [[layer valueForKey: key] rectValue];
    }

    if ([animation isKindOfClass: [CABasicAnimation class]]) {
        CABasicAnimation *basic = (CABasicAnimation *) animation;

        id fromValue = [basic fromValue];
        id toValue = [basic toValue];

        if (toValue == nil)
            toValue = [layer valueForKey: key];

        CGRect fromRect = [fromValue rectValue];
        CGRect toRect = [toValue rectValue];

        double timingScale = mediaTimingScale(animation, currentTime);

        CGRect resultRect;

        resultRect.origin.x =
                fromRect.origin.x +
                (toRect.origin.x - fromRect.origin.x) * timingScale;
        resultRect.origin.y =
                fromRect.origin.y +
                (toRect.origin.y - fromRect.origin.y) * timingScale;
        resultRect.size.width =
                fromRect.size.width +
                (toRect.size.width - fromRect.size.width) * timingScale;
        resultRect.size.height =
                fromRect.size.height +
                (toRect.size.height - fromRect.size.height) * timingScale;

        return resultRect;
    }

    return CGRectMake(0, 0, 0, 0);
}

static GLint interpolationFromName(NSString *name) {
    if (name == kCAFilterLinear)
        return GL_LINEAR;
    else if (name == kCAFilterNearest)
        return GL_NEAREST;
    else if ([name isEqualToString: kCAFilterLinear])
        return GL_LINEAR;
    else if ([name isEqualToString: kCAFilterNearest])
        return GL_NEAREST;
    else
        return GL_LINEAR;
}

void CATexImage2DCGImage(CGImageRef image) {
    static const uint8_t kTransparent[4] = { 0, 0, 0, 0 };

    size_t imageWidth = 0;
    size_t imageHeight = 0;
    CGBitmapInfo bitmapInfo = 0;
    CGDataProviderRef provider = NULL;
    CFDataRef data = NULL;
    const uint8_t *pixelBytes = NULL;

    /* darling-lol M57: layers can have nil contents, or a CGImage whose data
     * provider is unavailable under Darling; the old code dereferenced those
     * (O2DataProviderCopyData(NULL) / CFDataGetBytePtr(NULL)). */
    if (image != NULL) {
        provider = CGImageGetDataProvider(image);
        if (provider != NULL)
            data = CGDataProviderCopyData(provider);
    }

    if (data != NULL) {
        imageWidth = CGImageGetWidth(image);
        imageHeight = CGImageGetHeight(image);
        bitmapInfo = CGImageGetBitmapInfo(image);
        pixelBytes = CFDataGetBytePtr(data);
    }

    if (pixelBytes == NULL) {
        NSLog(@"LOLTEX no pixel data: image=%p provider=%p data=%p", image,
              provider, data);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, 1, 1, 0, GL_RGBA,
                     GL_UNSIGNED_BYTE, kTransparent);
        if (data != NULL)
            CFRelease(data);
        return;
    }

    GLenum glFormat = GL_BGRA;
    GLenum glType = GL_UNSIGNED_INT_8_8_8_8_REV;

    CGImageAlphaInfo alphaInfo = bitmapInfo & kCGBitmapAlphaInfoMask;
    CGBitmapInfo byteOrder = bitmapInfo & kCGBitmapByteOrderMask;

    switch (alphaInfo) {

    case kCGImageAlphaNone:
        break;

    case kCGImageAlphaPremultipliedLast:
        if (byteOrder == kO2BitmapByteOrder32Big) {
            glFormat = GL_RGBA;
            glType = GL_UNSIGNED_INT_8_8_8_8_REV;
        }
        break;

    case kCGImageAlphaPremultipliedFirst: // ARGB
        if (byteOrder == kCGBitmapByteOrder32Little) {
            glFormat = GL_BGRA;
            glType = GL_UNSIGNED_INT_8_8_8_8_REV;
        }
        break;

    case kCGImageAlphaLast:
        break;

    case kCGImageAlphaFirst:
        break;

    case kCGImageAlphaNoneSkipLast:
        break;

    case kCGImageAlphaNoneSkipFirst:
        break;

    case kCGImageAlphaOnly:
        break;
    }

    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, imageWidth, imageHeight, 0,
                 glFormat, glType, pixelBytes);

    CFRelease(data);
}

/* darling-lol M57: Chromium's macOS compositor presents frames through
 * DisplayCALayerTree, which sets CALayer.contents to an IOSurfaceRef (not a
 * CGImage). Upload such a surface directly as a texture. */
void CATexImage2DIOSurface(IOSurfaceRef surface) {
    static const uint8_t kTransparent[4] = { 0, 0, 0, 0 };

    size_t width = IOSurfaceGetWidth(surface);
    size_t height = IOSurfaceGetHeight(surface);
    size_t bytesPerRow = IOSurfaceGetBytesPerRow(surface);
    OSType pixelFormat = IOSurfaceGetPixelFormat(surface);
    void *base = IOSurfaceGetBaseAddress(surface);

    /* darling-lol M57 diagnostic (opt-in): is the delivered compositor frame
     * real? A zero base / all-zero pixels here means frame data never reached
     * the browser process. */
    if (getenv("M57_QC_TRACE") != 0) {
        unsigned int z = 0;
        unsigned long nonzero = 0, i;
        if (base != NULL && width != 0) {
            const unsigned char *p = (const unsigned char *)base;
            for (i = 0; i < width * 4 && i < 4096; i++)
                if (p[i]) nonzero++;
            z = (unsigned int)nonzero;
        }
        NSLog(@"M57TEXIOS w=%zu h=%zu bpr=%zu fmt=%08x base=%p first4k_nonzero=%u",
              width, height, bytesPerRow, (unsigned)pixelFormat, base, z);
    }

    if (base == NULL || width == 0 || height == 0) {
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, 1, 1, 0, GL_RGBA,
                     GL_UNSIGNED_BYTE, kTransparent);
        return;
    }

    GLenum glFormat = GL_BGRA;
    GLenum glType = GL_UNSIGNED_INT_8_8_8_8_REV;

    switch (pixelFormat) {
    case 'RGBA':
        glFormat = GL_RGBA;
        glType = GL_UNSIGNED_INT_8_8_8_8_REV;
        break;
    case 'BGRA':
    default:
        glFormat = GL_BGRA;
        glType = GL_UNSIGNED_INT_8_8_8_8_REV;
        break;
    }

    glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
    if (bytesPerRow != 0 && bytesPerRow >= width * 4)
        glPixelStorei(GL_UNPACK_ROW_LENGTH, (GLint)(bytesPerRow / 4));

    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, (GLsizei) width, (GLsizei) height,
                 0, glFormat, glType, base);

    glPixelStorei(GL_UNPACK_ROW_LENGTH, 0);
    glPixelStorei(GL_UNPACK_ALIGNMENT, 4);
}

- (void) _renderLayer: (CALayer *) layer
                    z: (CGFloat) z
          currentTime: (CFTimeInterval) currentTime
{
    NSNumber *textureId = [layer _textureId];
    GLuint texture = [textureId unsignedIntValue];
    GLboolean loadPixelData = GL_FALSE;

    if (texture == 0)
        loadPixelData = GL_TRUE;
    else {

        if (glIsTexture(texture) == GL_FALSE) {
            loadPixelData = GL_TRUE;
        }
        glBindTexture(GL_TEXTURE_2D, texture);
    }

    if (loadPixelData) {
        id contents = (id) layer.contents;

        if (contents != nil &&
            CFGetTypeID((CFTypeRef) contents) == IOSurfaceGetTypeID()) {
            CATexImage2DIOSurface((IOSurfaceRef) contents);
        } else {
            CATexImage2DCGImage((CGImageRef) contents);
        }

        GLint minFilter = interpolationFromName(layer.minificationFilter);
        GLint magFilter = interpolationFromName(layer.magnificationFilter);

        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, minFilter);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, magFilter);

        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
    }

    CGPoint anchorPoint =
            interpolatePointInLayerKey(layer, @"anchorPoint", currentTime);
    CGPoint position =
            interpolatePointInLayerKey(layer, @"position", currentTime);
    CGRect bounds = interpolateRectInLayerKey(layer, @"bounds", currentTime);
    CGFloat opacity =
            interpolateFloatInLayerKey(layer, @"opacity", currentTime);

    GLfloat textureVertices[4 * 2];
    GLfloat vertices[4 * 3];

    textureVertices[0] = 0;
    textureVertices[1] = 1;
    textureVertices[2] = 1;
    textureVertices[3] = 1;
    textureVertices[4] = 0;
    textureVertices[5] = 0;
    textureVertices[6] = 1;
    textureVertices[7] = 0;

    vertices[0] = 0;
    vertices[1] = 0;
    vertices[2] = z;

    vertices[3] = bounds.size.width;
    vertices[4] = 0;
    vertices[5] = z;

    vertices[6] = 0;
    vertices[7] = bounds.size.height;
    vertices[8] = z;

    vertices[9] = bounds.size.width;
    vertices[10] = bounds.size.height;
    vertices[11] = z;

    glPushMatrix();
    //  glTranslatef(width/2,height/2,0);
    glTexCoordPointer(2, GL_FLOAT, 0, textureVertices);
    glVertexPointer(3, GL_FLOAT, 0, vertices);

    glTranslatef(position.x - (bounds.size.width * anchorPoint.x),
                 position.y - (bounds.size.height * anchorPoint.y), 0);
    // glTranslatef(position.x,position.y,0);
    // glScalef(bounds.size.width,bounds.size.height,1);

    //  glRotatef(1,0,0,1);
    glColor4f(opacity, opacity, opacity, opacity);

    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);

    for (CALayer *child in layer.sublayers)
        [self _renderLayer: child z: z + 1 currentTime: currentTime];

    glPopMatrix();
}

- (void) render {
    glMatrixMode(GL_MODELVIEW);
    glLoadIdentity();

    glClearColor(0, 0, 0, 1);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

    glEnable(GL_DEPTH_TEST);
    glDepthFunc(GL_LEQUAL);

    glEnable(GL_TEXTURE_2D);
    glEnableClientState(GL_VERTEX_ARRAY);
    glEnableClientState(GL_TEXTURE_COORD_ARRAY);

    glEnable(GL_BLEND);
    glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);

    glAlphaFunc(GL_GREATER, 0);
    glEnable(GL_ALPHA_TEST);

    [self _renderLayer: _rootLayer z: 0 currentTime: CACurrentMediaTime()];

    glFlush();
}

- (void) endFrame {
}

@end
