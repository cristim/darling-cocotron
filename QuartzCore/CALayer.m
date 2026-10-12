#import <Foundation/NSDictionary.h>
#import <Foundation/NSInvocation.h>
#import <Foundation/NSMethodSignature.h>
#import <QuartzCore/CAAnimation.h>
#import <QuartzCore/CALayer.h>
#import <QuartzCore/CALayerContext.h>
#import <QuartzCore/CATransaction.h>
#import <IOSurface/IOSurface.h>
#import <OpenGL/OpenGL.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <sys/signal.h>
#include <errno.h>
#include <dirent.h>
#include <unistd.h>
#include <stdlib.h>
#include <pthread.h>
#include <dlfcn.h>

/* Darling has no WindowServer/CAContext service to carry Chromium's remote
 * layer tree from its GPU process to AppKit.  Keep the latest IOSurface in a
 * host-visible seqlocked slot; the X11 AppKit backend consumes this slot.
 * This is intentionally pixel transport, not guest object transport: guest
 * objects and globals are not coherent between Darling processes. */
#define DARLING_CA_FRAME_MAGIC 0x43414652u /* "CAFR" */
#define DARLING_CA_FRAME_BUFFERED_MAGIC 0x43414632u /* "CAF2" */
#define DARLING_CA_FRAME_BACK_BUFFER 0x40000000u
#define DARLING_CA_FRAME_CAPACITY (64u * 1024u * 1024u)
typedef struct {
    uint32_t magic;
    volatile uint32_t sequence;
    uint32_t width;
    uint32_t height;
    uint32_t bytesPerRow;
    uint32_t pixelFormat;
    uint64_t dataSize;
} DarlingCARemoteFrame;

static pthread_key_t committedSurfaceKey;
static pthread_key_t softwareSurfaceKey;
static pthread_once_t committedSurfaceOnce = PTHREAD_ONCE_INIT;
static void releaseCommittedSurface(void *surface) { CFRelease(surface); }
static void createCommittedSurfaceKey(void) {
    pthread_key_create(&committedSurfaceKey, releaseCommittedSurface);
    pthread_key_create(&softwareSurfaceKey, releaseCommittedSurface);
}
static void rememberCommittedSurface(IOSurfaceRef surface) {
    pthread_once(&committedSurfaceOnce, createCommittedSurfaceKey);
    IOSurfaceRef previous = pthread_getspecific(committedSurfaceKey);
    if (previous != surface) {
        CFRetain(surface);
        pthread_setspecific(committedSurfaceKey, surface);
        if (previous) CFRelease(previous);
    }
}
static pthread_mutex_t remoteFrameLock = PTHREAD_MUTEX_INITIALIZER;
static void publishRemoteIOSurfaceImpl(IOSurfaceRef surface, BOOL readback) {
    static DarlingCARemoteFrame *slot;
    static int fd = -1;
    /* The X11 frame protocol carries packed32-bit pixels. Planar decoder
     * buffers belong to the GPU video upload path, never whole-window frames. */
    if(IOSurfaceGetPlaneCount(surface)>1 || IOSurfaceGetBytesPerElement(surface)!=4){
        static unsigned ignored;
        if(getenv("DARLING_CA_FRAME_TRACE") && ignored++<8)
            fprintf(stderr,"CA_FRAME_UNSUPPORTED planes=%zu bpe=%zu size=%zux%zu\n",IOSurfaceGetPlaneCount(surface),IOSurfaceGetBytesPerElement(surface),IOSurfaceGetWidth(surface),IOSurfaceGetHeight(surface));
        return;
    }
    size_t width = IOSurfaceGetWidth(surface);
    size_t height = IOSurfaceGetHeight(surface);
    size_t rowBytes = IOSurfaceGetBytesPerRow(surface);
    size_t dataSize = rowBytes * height;
    void *base = IOSurfaceGetBaseAddress(surface);
    if (!base || !width || !height || !rowBytes ||
        dataSize > DARLING_CA_FRAME_CAPACITY)
        return;

    /* Readback may itself finish a software write and enter this publisher.
     * Do it before taking the frame lock; serialize only file initialization
     * and snapshot publication across threads in this process. */
    pthread_once(&committedSurfaceOnce, createCommittedSurfaceKey);
    IOSurfaceRef softwareSurface = pthread_getspecific(softwareSurfaceKey);
    if (!readback && softwareSurface != surface) {
        CFRetain(surface);
        pthread_setspecific(softwareSurfaceKey, surface);
        if (softwareSurface) CFRelease(softwareSurface);
        softwareSurface = surface;
    }
    BOOL softwarePixels = softwareSurface == surface;
    /* Only the process/context that completed GPU readback owns fresh pixels.
     * A browser snapshot of shared backing may race or trail that publisher. */
    if(readback && !softwarePixels && getenv("RCLOL_GPU_DIRECT_PRESENT")){
        typedef int (*PresentFn)(IOSurfaceRef);
        PresentFn present=(PresentFn)dlsym(RTLD_DEFAULT,"CGLPresentIOSurface");
        if(present && present(surface)){rememberCommittedSurface(surface);return;}
    }
    if (readback && !softwarePixels && CGLReadbackIOSurface(surface) != kCGLNoError)
        return;
    softwarePixels = pthread_getspecific(softwareSurfaceKey) == surface;
    pthread_mutex_lock(&remoteFrameLock);
    if (!slot) {
        char path[128];
        /* darling-lol M58c: one slot file per PUBLISHER process. A single
         * per-uid slot was raced by every publishing process (GPU layer tree
         * + browser DisplayCALayerTree), corrupting the odd/even seqlock for
         * the consumer: 655/663 probes read a torn/unstable frame. Per-pid
         * slots keep each file single-writer, so the seqlock holds. */
        snprintf(path, sizeof(path), "/dev/shm/darling-ca-frame-%u-%d",
            getuid(), (int) getpid());
        fd = open(path, O_CREAT | O_RDWR, 0600);
        if (fd < 0 || ftruncate(fd, sizeof(*slot) + DARLING_CA_FRAME_CAPACITY)) {
            pthread_mutex_unlock(&remoteFrameLock);
            return;
        }
        slot = mmap(NULL, sizeof(*slot) + DARLING_CA_FRAME_CAPACITY,
                    PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
        if (slot == MAP_FAILED) {
            slot = NULL;
            pthread_mutex_unlock(&remoteFrameLock);
            return;
        }

        /* darling-lol M58c: reap slot files left by dead publishers
         * (64 MB each). Slot names end in the publishing guest pid. */
        {
            DIR *dir = opendir("/dev/shm");
            char prefix[32];
            snprintf(prefix, sizeof(prefix), "darling-ca-frame-%u-", getuid());
            size_t prefixLen = strlen(prefix);
            if (dir) {
                struct dirent *ent;
                while ((ent = readdir(dir)) != NULL) {
                    if (strncmp(ent->d_name, prefix, prefixLen) != 0)
                        continue;
                    int stalePid = atoi(ent->d_name + prefixLen);
                    if (stalePid > 0 && stalePid != (int) getpid() &&
                        kill(stalePid, 0) != 0 && errno == ESRCH) {
                        char stale[128];
                        snprintf(stale, sizeof(stale), "/dev/shm/%s",
                            ent->d_name);
                        unlink(stale);
                    }
                }
                closedir(dir);
            }
        }
    }

    rememberCommittedSurface(surface);

    /* CGLTexImageIOSurface2D's Mesa fallback cannot provide true shared GL
     * storage.  Materialize the completed compositor texture first. */
    IOSurfaceLock(surface, kIOSurfaceLockReadOnly, NULL);
    uint32_t sequence = slot->sequence;
    BOOL buffered = dataSize <= DARLING_CA_FRAME_CAPACITY / 2;
    size_t offset = buffered && !(slot->magic == DARLING_CA_FRAME_BUFFERED_MAGIC &&
        (slot->pixelFormat & DARLING_CA_FRAME_BACK_BUFFER))
        ? DARLING_CA_FRAME_CAPACITY / 2 : 0;
    /* Keep the completed front buffer readable during the bulk copy. Only
     * publishing its new header needs the short seqlock critical section.
     * Large legacy frames still use one buffer and must invalidate first. */
    if (!buffered || (slot->magic == DARLING_CA_FRAME_MAGIC &&
                      slot->dataSize > DARLING_CA_FRAME_CAPACITY / 2)) {
        slot->sequence = (sequence + 1) | 1;
        __sync_synchronize();
    }
    memcpy((char *)(slot + 1) + offset, base, dataSize);
    __sync_synchronize();
    slot->sequence = (sequence + 1) | 1;
    __sync_synchronize();
    slot->magic = buffered ? DARLING_CA_FRAME_BUFFERED_MAGIC : DARLING_CA_FRAME_MAGIC;
    slot->width = (uint32_t)width;
    slot->height = (uint32_t)height;
    slot->bytesPerRow = (uint32_t)rowBytes;
    /* This is an internal transport header; two upper bits carry provenance
     * and buffer location rather than the original IOSurface fourcc. */
    slot->pixelFormat = ((uint32_t)IOSurfaceGetPixelFormat(surface) & 0x3fffffffu) |
        (softwarePixels ? 0x80000000u : 0) |
        (offset ? DARLING_CA_FRAME_BACK_BUFFER : 0);
    slot->dataSize = dataSize;
    __sync_synchronize();
    slot->sequence = (sequence + 2) & ~1u;
    IOSurfaceUnlock(surface, kIOSurfaceLockReadOnly, NULL);
    futimes(fd, NULL); /* mmap writes alone do not refresh publisher ordering */

    /* darling-lol M58c diagnostic (opt-in via M58_PRES_TRACE): publisher
     * cadence. p=publish, P=publish whose first 8 rows are all-zero,
     * f=first publish in this process (carries the size). */
    if (getenv("M58_PRES_TRACE")) {
        static FILE *plog;
        if (!plog) {
            char ppath[128];
            snprintf(ppath, sizeof(ppath),
                "/dev/shm/m58c-publish-%d", (int) getpid());
            plog = fopen(ppath, "w");
            if (plog)
                fprintf(plog,
                    "pid=%d %zux%zu first\n", (int) getpid(), width, height);
        }
        if (plog) {
            BOOL blank = YES;
            size_t scan = 8 * rowBytes;
            const unsigned char *p8 = (const unsigned char *) base;
            for (size_t i = 0; i + 3 < scan && blank; i += 4)
                if (p8[i] | p8[i + 1] | p8[i + 2])
                    blank = NO;
            fputc(blank ? 'P' : 'p', plog);
            fflush(plog);
        }
    }
    pthread_mutex_unlock(&remoteFrameLock);
}

static void publishRemoteIOSurface(IOSurfaceRef surface) {
    publishRemoteIOSurfaceImpl(surface, YES);
}

/* Software paint already wrote the backing pixels: do not replace them with
 * a GL texture readback. IOSurface calls this only after a write unlock. */
void DarlingCAPublishIOSurfacePixels(IOSurfaceRef surface) {
    publishRemoteIOSurfaceImpl(surface, NO);
}

/* Remote CA reuses a layer and its IOSurface across frames. GPU writes do
 * not necessarily call setContents again; refresh pixels at outer commit. */
void DarlingCAPublishCommittedIOSurface(void) {
    pthread_once(&committedSurfaceOnce, createCommittedSurfaceKey);
    IOSurfaceRef surface = pthread_getspecific(committedSurfaceKey);
    if (surface) publishRemoteIOSurface(surface);
}

NSString *const kCAFilterLinear = @"linear";
NSString *const kCAFilterNearest = @"nearest";
NSString *const kCAFilterTrilinear = @"trilinear";

NSString *const kCAGravityResizeAspect = @"resizeAspect";
NSString *const kCAGravityResizeAspectFill = @"resizeAspectFill";

NSString *const kCAGravityCenter = @"center";
NSString *const kCAGravityTop = @"top";
NSString *const kCAGravityBottom = @"bottom";
NSString *const kCAGravityLeft = @"left";
NSString *const kCAGravityRight = @"right";
NSString *const kCAGravityTopLeft = @"topLeft";
NSString *const kCAGravityTopRight = @"topRight";
NSString *const kCAGravityBottomLeft = @"bottomLeft";
NSString *const kCAGravityBottomRight = @"bottomRight";
NSString *const kCAGravityResize = @"resize";

NSString *const kCAOnOrderIn = @"onOrderIn";
NSString *const kCAOnOrderOut = @"onOrderOut";
NSString *const kCATransition = @"transition";

NSString *const kCAContentsFormatRGBA8Uint = @"RGBA8";
NSString *const kCAContentsFormatRGBA16Float = @"RGBAh";
NSString *const kCAContentsFormatGray8Uint = @"Gray8";

@implementation CALayer

+ layer {
    return [[[self alloc] init] autorelease];
}

- (CALayerContext *) _context {
    return _context;
}

- (void) _setContext: (CALayerContext *) context {
    if (_context != context) {
        [_context deleteTextureId: _textureId];
        [_textureId release];
        _textureId = nil;
    }

    _context = context;
    [_sublayers makeObjectsPerformSelector: @selector(_setContext:)
                                withObject: context];
}

- (CALayer *) superlayer {
    return _superlayer;
}

- (NSArray *) sublayers {
    return _sublayers;
}

- (void) setSublayers: (NSArray *) sublayers {
    NSArray *oldSublayers = _sublayers;
    sublayers = [sublayers copy];
    /* A child only retains its parent through the parent's array.  Clear
     * its non-owning back pointers before dropping the old array. */
    for (CALayer *child in oldSublayers) {
        if ([sublayers indexOfObjectIdenticalTo: child] == NSNotFound) {
            [child _setSuperLayer: nil];
            [child _setContext: nil];
        }
    }
    _sublayers = sublayers;
    [_sublayers makeObjectsPerformSelector: @selector(_setSuperLayer:)
                                withObject: self];
    [_sublayers makeObjectsPerformSelector: @selector(_setContext:)
                                withObject: _context];
    [oldSublayers release];
}

- (id<CALayerDelegate>) delegate {
    return _delegate;
}

- (void) setDelegate: (id<CALayerDelegate>)value {
    _delegate = value;
}

- (CGPoint) anchorPoint {
    return _anchorPoint;
}

- (void) setAnchorPoint: (CGPoint) value {
    _anchorPoint = value;
}

- (CGPoint) position {
    return _position;
}

- (void) setPosition: (CGPoint) value {
    CAAnimation *animation = [self animationForKey: @"position"];

    if (animation == nil && ![CATransaction disableActions]) {
        id action = [self actionForKey: @"position"];

        if (action != nil)
            [self addAnimation: action forKey: @"position"];
    }

    _position = value;
}

- (CGRect) bounds {
    return _bounds;
}

- (void) setBounds: (CGRect) value {
    CAAnimation *animation = [self animationForKey: @"bounds"];

    if (animation == nil && ![CATransaction disableActions]) {
        id action = [self actionForKey: @"bounds"];

        if (action != nil)
            [self addAnimation: action forKey: @"bounds"];
    }

    _bounds = value;
}

- (CGRect) frame {
    CGRect result;

    result.size = _bounds.size;
    result.origin.x = _position.x - result.size.width * _anchorPoint.x;
    result.origin.y = _position.y - result.size.height * _anchorPoint.y;

    return result;
}

- (void) setFrame: (CGRect) value {

    CGPoint position;

    position.x = value.origin.x + value.size.width * _anchorPoint.x;
    position.y = value.origin.y + value.size.height * _anchorPoint.y;

    [self setPosition: position];

    CGRect bounds = _bounds;

    bounds.size = value.size;

    [self setBounds: bounds];
}

- (CGFloat) opacity {
    return _opacity;
}

- (void) setOpacity: (CGFloat) value {
    CAAnimation *animation = [self animationForKey: @"opacity"];

    if (animation == nil && ![CATransaction disableActions]) {
        id action = [self actionForKey: @"opacity"];

        if (action != nil)
            [self addAnimation: action forKey: @"opacity"];
    }

    _opacity = value;
}

- (BOOL) opaque {
    return _opaque;
}

- (void) setOpaque: (BOOL) value {
    _opaque = value;
}

/* darling-lol M57: Chromium sets a layer's geometryFlipped flag when hosting
 * web content. */
- (BOOL) geometryFlipped {
    return _geometryFlipped;
}

- (void) setGeometryFlipped: (BOOL) value {
    _geometryFlipped = value;
}

- (id) contents {
    return _contents;
}

- (void) setContents: (id) value {
    /* darling-lol M57: a live compositor (e.g. Chromium) replaces a layer's
     * contents every frame. Drop the cached GL texture so CARenderer uploads
     * the new image instead of reusing the first (possibly empty) one, then
     * present the updated tree (Darling's NSTimer-driven frame loop does not
     * fire for this context). */
    BOOL needsPresent = NO;
    if (_context != nil && _contents != value) {
        [_context deleteTextureId: _textureId];
        [_textureId release];
        _textureId = nil;
        needsPresent = YES;
    }
    value = [value retain];
    [_contents release];
    _contents = value;

    /* Remote CA trees can have a context without a local drawable. Their
     * IOSurface still needs a pixel handoff to the X11 consumer. */
    if (value != nil &&
        CFGetTypeID((CFTypeRef)value) == IOSurfaceGetTypeID())
        if(getenv("DARLING_CA_PRESENT_AT_COMMIT"))rememberCommittedSurface((IOSurfaceRef)value);
        else publishRemoteIOSurface((IOSurfaceRef)value);

    if (needsPresent) {
        /* darling-lol M57 diagnostic (opt-in): report what kind of contents
         * Chromium delivers (IOSurface == a real compositor frame). */
        if (getenv("M57_QC_TRACE") != 0) {
            BOOL isSurf = (value != nil &&
                CFGetTypeID((CFTypeRef)value) == IOSurfaceGetTypeID());
            NSLog(@"M57SETCONTENTS class=%s iosurface=%d ctx=%p",
                  value ? object_getClassName(value) : "nil", (int)isSurf, _context);
        }
        [_context render];
        [_context flush];
    }
}

- (void) setContentsChanged {
    /* Chromium can reuse an IOSurface and update its pixels without replacing
     * the contents object. Invalidate the cached texture and publish the new
     * pixels just as for a contents replacement. */
    [_context deleteTextureId: _textureId];
    [_textureId release];
    _textureId = nil;
    if (_contents != nil &&
        CFGetTypeID((CFTypeRef)_contents) == IOSurfaceGetTypeID())
        if(getenv("DARLING_CA_PRESENT_AT_COMMIT"))rememberCommittedSurface((IOSurfaceRef)_contents);
        else publishRemoteIOSurface((IOSurfaceRef)_contents);
    if (_context != nil) {
        [_context render];
        [_context flush];
    }
}

- (CATransform3D) transform {
    return _transform;
}

- (void) setTransform: (CATransform3D) value {
    _transform = value;
}

- (CATransform3D) sublayerTransform {
    return _sublayerTransform;
}

- (void) setSublayerTransform: (CATransform3D) value {
    _sublayerTransform = value;
}

- (NSString *) minificationFilter {
    return _minificationFilter;
}

- (void) setMinificationFilter: (NSString *) value {
    value = [value copy];
    [_minificationFilter release];
    _minificationFilter = value;
}

- (NSString *) magnificationFilter {
    return _magnificationFilter;
}

- (void) setMagnificationFilter: (NSString *) value {
    value = [value copy];
    [_magnificationFilter release];
    _magnificationFilter = value;
}

- init {
    _superlayer = nil;
    _sublayers = [NSArray new];
    _delegate = nil;
    _anchorPoint = CGPointMake(0.5, 0.5);
    _position = CGPointZero;
    _bounds = CGRectZero;
    _opacity = 1.0;
    _opaque = YES;
    _contents = nil;
    _transform = CATransform3DIdentity;
    _sublayerTransform = CATransform3DIdentity;
    _minificationFilter = kCAFilterLinear;
    _magnificationFilter = kCAFilterLinear;
    _animations = [[NSMutableDictionary alloc] init];
    return self;
}

- (void) dealloc {
    for (CALayer *child in _sublayers) {
        [child _setSuperLayer: nil];
        [child _setContext: nil];
    }
    [_sublayers release];
    [_animations release];
    [_minificationFilter release];
    [_magnificationFilter release];
    [super dealloc];
}

- (void) _setSuperLayer: (CALayer *) parent {
    _superlayer = parent;
}

- (void) _removeSublayer: (CALayer *) child {
    NSMutableArray *layers = [_sublayers mutableCopy];
    [layers removeObjectIdenticalTo: child];
    [self setSublayers: layers];
    [layers release];
}

- (void) addSublayer: (CALayer *) layer {
    [self setSublayers: [_sublayers arrayByAddingObject: layer]];
}

- (void) insertSublayer: (CALayer *) layer atIndex: (unsigned) index {
    if (!layer)
        return;
    [layer removeFromSuperlayer];
    NSMutableArray *layers = [_sublayers mutableCopy];
    NSUInteger boundedIndex = index > [layers count] ? [layers count] : index;
    [layers insertObject: layer atIndex: boundedIndex];
    [self setSublayers: layers];
    [layers release];
}

- (void) insertSublayer: (CALayer *) layer below: (CALayer *) sibling {
    NSUInteger index = [_sublayers indexOfObjectIdenticalTo: sibling];
    if (index == NSNotFound)
        index = 0;
    [self insertSublayer: layer atIndex: (unsigned)index];
}

- (void) insertSublayer: (CALayer *) layer above: (CALayer *) sibling {
    NSUInteger index = [_sublayers indexOfObjectIdenticalTo: sibling];
    if (index == NSNotFound)
        index = [_sublayers count];
    else
        index++;
    [self insertSublayer: layer atIndex: (unsigned)index];
}

- (void) replaceSublayer: (CALayer *) layer with: (CALayer *) other {
    NSMutableArray *layers = [_sublayers mutableCopy];
    NSUInteger index = [_sublayers indexOfObjectIdenticalTo: layer];

    [layers replaceObjectAtIndex: index withObject: other];

    [self setSublayers: layers];
    [layers release];

    layer->_superlayer = nil;
}

- (void) display {
    if ([_delegate respondsToSelector: @selector(displayLayer:)])
        [_delegate displayLayer: self];
    else {
#if 0

#warning create bitmap context

    [self drawInContext:context];
    _contents=image;
    [self setContents:image];
#endif
    }
}

- (void) displayIfNeeded {
}

- (void) drawInContext: (CGContextRef) context {
    if ([_delegate respondsToSelector: @selector(drawLayer:inContext:)])
        [_delegate drawLayer: self inContext: context];
}

- (BOOL) needsDisplay {
    return _needsDisplay;
}

- (void) removeFromSuperlayer {
    /* Removing the child from its parent's array may release the last
     * external reference to this layer. Keep it alive until cleanup ends. */
    [self retain];
    CALayer *parent = _superlayer;
    _superlayer = nil;
    [parent _removeSublayer: self];
    [self _setContext: nil];
    [self release];
}

- (void) setNeedsDisplay {
    _needsDisplay = YES;
}

- (void) setNeedsDisplayInRect: (CGRect) rect {
    _needsDisplay = YES;
}

- (void) addAnimation: (CAAnimation *) animation forKey: (NSString *) key {
    if (_context == nil)
        return;

    [_animations setObject: animation forKey: key];
    [_context startTimerIfNeeded];
}

/* darling-lol M57: used by CALayerContext to decide whether the on-demand frame
 * timer should keep re-arming. With no animations there is no reason to render
 * continuously; contents changes drive presentation directly. */
- (BOOL) _treeHasAnimations {
    if ([_animations count] > 0)
        return YES;
    for (CALayer *child in _sublayers) {
        if ([child _treeHasAnimations])
            return YES;
    }
    return NO;
}

- (CAAnimation *) animationForKey: (NSString *) key {
    return [_animations objectForKey: key];
}

- (void) removeAllAnimations {
    [_animations removeAllObjects];
}

- (void) removeAnimationForKey: (NSString *) key {
    [_animations removeObjectForKey: key];
}

- (NSArray *) animationKeys {
    return [_animations allKeys];
}

- valueForKey: (NSString *) key {
    // FIXME: KVC appears broken for structs

    if ([key isEqualToString: @"bounds"])
        return [NSValue valueWithRect: _bounds];
    if ([key isEqualToString: @"frame"])
        return [NSValue valueWithRect: [self frame]];

    return [super valueForKey: key];
}

- (id<CAAction>) actionForKey: (NSString *) key {
    CABasicAnimation *basic = [CABasicAnimation animationWithKeyPath: key];

    [basic setFromValue: [self valueForKey: key]];

    return basic;
}

- (NSNumber *) _textureId {
    return _textureId;
}

- (void) _setTextureId: (NSNumber *) value {
    value = [value copy];
    [_textureId release];
    _textureId = value;
}

/* darling-lol M57: property accessors Chromium's layer hosting needs. */

- (NSUInteger) autoresizingMask { return _autoresizingMask; }
- (void) setAutoresizingMask: (NSUInteger) v { _autoresizingMask = v; }

- (BOOL) masksToBounds { return _masksToBounds; }
- (void) setMasksToBounds: (BOOL) v { _masksToBounds = v; }

- (CGFloat) cornerRadius { return _cornerRadius; }
- (void) setCornerRadius: (CGFloat) v { _cornerRadius = v; }

- (CGColorRef) backgroundColor { return _backgroundColor; }
- (void) setBackgroundColor: (CGColorRef) v { _backgroundColor = v; }

- (CGFloat) borderWidth { return _borderWidth; }
- (void) setBorderWidth: (CGFloat) v { _borderWidth = v; }

- (CGColorRef) borderColor { return _borderColor; }
- (void) setBorderColor: (CGColorRef) v { _borderColor = v; }

- (CGFloat) zPosition { return _zPosition; }
- (void) setZPosition: (CGFloat) v { _zPosition = v; }

- (BOOL) isHidden { return _hidden; }
- (BOOL) hidden { return _hidden; }
- (void) setHidden: (BOOL) v { _hidden = v; }

- (BOOL) isDoubleSided { return _doubleSided; }
- (BOOL) doubleSided { return _doubleSided; }
- (void) setDoubleSided: (BOOL) v { _doubleSided = v; }

- (BOOL) needsDisplayOnBoundsChange { return _needsDisplayOnBoundsChange; }
- (void) setNeedsDisplayOnBoundsChange: (BOOL) v { _needsDisplayOnBoundsChange = v; }

- (BOOL) shouldRasterize { return _shouldRasterize; }
- (void) setShouldRasterize: (BOOL) v { _shouldRasterize = v; }

- (CGFloat) rasterizationScale { return _rasterizationScale; }
- (void) setRasterizationScale: (CGFloat) v { _rasterizationScale = v; }

- (BOOL) allowsEdgeAntialiasing { return _allowsEdgeAntialiasing; }
- (void) setAllowsEdgeAntialiasing: (BOOL) v { _allowsEdgeAntialiasing = v; }

- (BOOL) allowsGroupOpacity { return _allowsGroupOpacity; }
- (void) setAllowsGroupOpacity: (BOOL) v { _allowsGroupOpacity = v; }

- (BOOL) allowsGroupBlending { return _allowsGroupBlending; }
- (void) setAllowsGroupBlending: (BOOL) v { _allowsGroupBlending = v; }

- (BOOL) allowsHitTesting { return _allowsHitTesting; }
- (void) setAllowsHitTesting: (BOOL) v { _allowsHitTesting = v; }

- (BOOL) drawsAsynchronously { return _drawsAsynchronously; }
- (void) setDrawsAsynchronously: (BOOL) v { _drawsAsynchronously = v; }

- (CGFloat) contentsScale { return _contentsScale; }
- (void) setContentsScale: (CGFloat) v { _contentsScale = v; }

- (NSString *) contentsGravity { return _contentsGravity; }
- (void) setContentsGravity: (NSString *) v {
    v = [v copy]; [_contentsGravity release]; _contentsGravity = v;
}

- (CGRect) contentsRect { return _contentsRect; }
- (void) setContentsRect: (CGRect) v { _contentsRect = v; }

- (CGRect) contentsCenter { return _contentsCenter; }
- (void) setContentsCenter: (CGRect) v { _contentsCenter = v; }

- (CGFloat) anchorPointZ { return _anchorPointZ; }
- (void) setAnchorPointZ: (CGFloat) v { _anchorPointZ = v; }

- (CGFloat) shadowOpacity { return _shadowOpacity; }
- (void) setShadowOpacity: (CGFloat) v { _shadowOpacity = v; }

- (CGSize) shadowOffset { return _shadowOffset; }
- (void) setShadowOffset: (CGSize) v { _shadowOffset = v; }

- (CGFloat) shadowRadius { return _shadowRadius; }
- (void) setShadowRadius: (CGFloat) v { _shadowRadius = v; }

- (CGColorRef) shadowColor { return _shadowColor; }
- (void) setShadowColor: (CGColorRef) v { _shadowColor = v; }

- (id) shadowPath { return _shadowPath; }
- (void) setShadowPath: (id) v { v = [v retain]; [_shadowPath release]; _shadowPath = v; }

- (float) minificationFilterBias { return _minificationFilterBias; }
- (void) setMinificationFilterBias: (float) v { _minificationFilterBias = v; }

- (unsigned int) edgeAntialiasingMask { return _edgeAntialiasingMask; }
- (void) setEdgeAntialiasingMask: (unsigned int) v { _edgeAntialiasingMask = v; }

- (NSArray *) filters { return _filters; }
- (void) setFilters: (NSArray *) v { v = [v copy]; [_filters release]; _filters = v; }

- (NSArray *) backgroundFilters { return _backgroundFilters; }
- (void) setBackgroundFilters: (NSArray *) v { v = [v copy]; [_backgroundFilters release]; _backgroundFilters = v; }

- (id) compositingFilter { return _compositingFilter; }
- (void) setCompositingFilter: (id) v { v = [v retain]; [_compositingFilter release]; _compositingFilter = v; }

- (NSDictionary *) style { return _style; }
- (void) setStyle: (NSDictionary *) v { v = [v copy]; [_style release]; _style = v; }

- (NSArray *) actions { return _actions; }
- (void) setActions: (NSArray *) v { v = [v copy]; [_actions release]; _actions = v; }

/* Layout hooks: Cocotron does not run a layout pass, so these are no-ops
 * (except layoutSublayers, if present, which delegates to the delegate). */
- (void) setNeedsLayout { }
- (void) layoutIfNeeded { }
- (BOOL) needsLayout { return NO; }
- (void) layoutSublayers { }

@end
