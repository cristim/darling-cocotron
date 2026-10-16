/*
 * This file is part of Darling.
 *
 * Copyright (C) 2022 Darling developers
 *
 * Darling is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * Darling is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Darling.  If not, see <http://www.gnu.org/licenses/>.
 */

#define GL_GLEXT_PROTOTYPES 1
#import "CAMetalLayerInternal.h"
#import "CAMetalDrawableInternal.h"
#import <Foundation/NSRaise.h>
#import <Metal/MTLDeviceInternal.h>
#import <QuartzCore/CALayerContext.h>
#import <Metal/stubs.h>

// Wait-site counters (flag file /tmp/metal-debug-waits, checked once at process start): the same summary the Indium
// hand-off waits write, so the drawable hand-out and the command-buffer hand-offs appear in one histogram.
#include <indium/waits.private.hpp>

#include <algorithm>
#include <cstdio>
#include <unistd.h>
#include <map>
#include <mutex>
#include <string>
#include <vector>
#import <dispatch/dispatch.h>

// Diagnostics are off unless /tmp/metal-debug-trace exists when the process starts.
static bool darlingMetalDebug()
{
	static const bool enabled = access("/tmp/metal-debug-trace", F_OK) == 0;
	return enabled;
}

// Diagnostic trace of the drawable/presentation flow, written to the guest's /tmp/metal-trace.log.
// Rate limited: the first events and then every hundredth.
static void darlingMetalTrace(const char* what, long a, long b)
{
	if (!darlingMetalDebug()) {
		return;
	}
	static int count = 0;
	int n = __sync_add_and_fetch(&count, 1);
	if (n > 80 && n % 100 != 0) {
		return;
	}
	if (FILE* log = fopen("/tmp/metal-trace.log", "a")) {
		fprintf(log, "%.3f #%d %s main=%d a=%ld b=%ld\n", CACurrentMediaTime(), n, what, (int) [NSThread isMainThread], a, b);
		fclose(log);
	}
}

// Cheap aggregated timings (flag file /tmp/metal-debug-timing in the guest when the process starts), printed every 5 s.
static void darlingMetalTiming(const char* what, double seconds)
{
	static const bool enabled = access("/tmp/metal-debug-timing", F_OK) == 0;
	if (!enabled) {
		return;
	}
	struct Stat { double sum = 0, max = 0; unsigned long count = 0; };
	static std::mutex lock;
	static std::map<std::string, Stat> stats;
	static double last = 0;
	std::lock_guard<std::mutex> guard(lock);
	Stat& stat = stats[what];
	stat.sum += seconds;
	stat.count++;
	if (seconds > stat.max) stat.max = seconds;
	double now = CACurrentMediaTime();
	if (now - last >= 5) {
		last = now;
		if (FILE* log = fopen("/tmp/metal-trace.log", "a")) {
			fprintf(log, "timing@%.0f:", now);
			for (auto& entry: stats) {
				fprintf(log, " %s[n=%lu avg=%.0fms max=%.0fms]", entry.first.c_str(), entry.second.count, entry.second.sum / entry.second.count * 1000, entry.second.max * 1000);
			}
			fprintf(log, "\n");
			fclose(log);
		}
		stats.clear();
	}
}

extern "C" void darlingQCTiming(const char* what, double seconds)
{
	darlingMetalTiming(what, seconds);
}

#import "CALayerInternal.h"

static void reportGLErrors(void) {
#if 0
	GLenum err;

	while ((err = glGetError()) != GL_NO_ERROR) {
		printf("*** OPENGL ERROR: %d ***\n", err);
	}
#endif
};

@implementation CAMetalLayer

#if DARLING_METAL_ENABLED
// FIXME: this breaks inheritance from CAMetalLayer.
//        the problem is that we need some C++ ivars, but we can't put those in the public header
//        and this code needs to compile on 32-bit (so it can't use non-fragile ivars).
//        maybe we could keep the troublesome ivars in an associated object...
//
//        then again, maybe we could get away with stubbing the entire class when compiling for 32-bit
//        since Metal is unavailable for 32-bit code.
+ (instancetype)allocWithZone: (NSZone*)zone
{
	if (self == [CAMetalLayer class]) {
		return [CAMetalLayerInternal allocWithZone: zone];
	} else {
		return [super allocWithZone: zone];
	}
}
#endif

- (id<MTLDevice>)device
{
	NSInvalidAbstractInvocation();
	return nil;
}

- (void)setDevice: (id<MTLDevice>)device
{
	NSInvalidAbstractInvocation();
}

- (id<MTLDevice>)preferredDevice
{
	NSInvalidAbstractInvocation();
	return nil;
}

- (MTLPixelFormat)pixelFormat
{
	NSInvalidAbstractInvocation();
	return MTLPixelFormatInvalid;
}

- (void)setPixelFormat: (MTLPixelFormat)pixelFormat
{
	NSInvalidAbstractInvocation();
}

- (CGColorSpaceRef)colorspace
{
	NSInvalidAbstractInvocation();
	return NULL;
}

- (void)setColorspace: (CGColorSpaceRef)colorspace
{
	NSInvalidAbstractInvocation();
}

- (BOOL)framebufferOnly
{
	NSInvalidAbstractInvocation();
	return YES;
}

- (void)setFramebufferOnly: (BOOL)framebufferOnly
{
	NSInvalidAbstractInvocation();
}

- (CGSize)drawableSize
{
	NSInvalidAbstractInvocation();
	return CGSizeZero;
}

- (void)setDrawableSize: (CGSize)drawableSize
{
	NSInvalidAbstractInvocation();
}

- (BOOL)presentsWithTransaction
{
	NSInvalidAbstractInvocation();
	return NO;
}

- (void)setPresentsWithTransaction: (BOOL)presentsWithTransaction
{
	NSInvalidAbstractInvocation();
}

- (BOOL)displaySyncEnabled
{
	NSInvalidAbstractInvocation();
	return NO;
}

- (void)setDisplaySyncEnabled: (BOOL)displaySyncEnabled
{
	NSInvalidAbstractInvocation();
}

- (BOOL)wantsExtendedDynamicRangeContent
{
	NSInvalidAbstractInvocation();
	return NO;
}

- (void)setWantsExtendedDynamicRangeContent: (BOOL)wantsExtendedDynamicRangeContent
{
	NSInvalidAbstractInvocation();
}

- (CAEDRMetadata*)EDRMetadata
{
	NSInvalidAbstractInvocation();
	return nil;
}

- (void)setEDRMetadata: (CAEDRMetadata*)EDRMetadata
{
	NSInvalidAbstractInvocation();
}

- (NSUInteger)maximumDrawableCount
{
	NSInvalidAbstractInvocation();
	return 0;
}

- (void)setMaximumDrawableCount: (NSUInteger)maximumDrawableCount
{
	NSInvalidAbstractInvocation();
}

- (BOOL)allowsNextDrawableTimeout
{
	NSInvalidAbstractInvocation();
	return NO;
}

- (void)setAllowsNextDrawableTimeout: (BOOL)allowsNextDrawableTimeout
{
	NSInvalidAbstractInvocation();
}

- (NSDictionary*)developerHUDProperties
{
	NSInvalidAbstractInvocation();
	return nil;
}

- (void)setDeveloperHUDProperties: (NSDictionary*)developerHUDProperties
{
	NSInvalidAbstractInvocation();
}

- (id<CAMetalDrawable>)nextDrawable
{
	NSInvalidAbstractInvocation();
	return nil;
}

@end

#include <array>
#include <atomic>
#include <chrono>
#include <mutex>
#include <unistd.h>
namespace {
struct PresentIntervalSample { std::atomic<int64_t> queued{0}, renderStart{0}, renderDone{0}, flushDone{0}; };
static int64_t presentIntervalNow() { return std::chrono::duration_cast<std::chrono::nanoseconds>(std::chrono::steady_clock::now().time_since_epoch()).count(); }
static PresentIntervalSample* beginPresentIntervalSample() {
 static const bool enabled = [] { FILE* flag = fopen("/tmp/metal-frame-interval-capture", "r"); if (!flag) return false; fclose(flag); return true; }();
 if (!enabled) return nullptr;
 static std::atomic<bool> finished{false};
 static std::mutex captureMutex;
 // Never reuse a callback's timestamp storage. A delayed main-queue callback
 // must not stall the recorder or write into a subsequent capture. All
 // storage stays alive until process exit; 64 blocks cap its size at 4 MiB.
 static std::array<std::array<PresentIntervalSample,2048>,64> blocks;
 static size_t count = 0;
 static unsigned block = 0, seriesBlocks = 0;
 static const bool testing = getenv("RIOT_FRAME_CAPTURE_TEST") != nullptr;
 if (finished.load(std::memory_order_relaxed)) {
  static std::atomic<unsigned> checks{0};
  if (checks.fetch_add(1, std::memory_order_relaxed) % (testing ? 8 : 128)) return nullptr;
  // Explicitly rearm a bounded eight-block capture in the same match. Keep
  // filenames increasing so an earlier workload's measurements survive.
  if (access("/tmp/metal-frame-interval-repeat", F_OK) != 0) return nullptr;
  std::lock_guard<std::mutex> guard(captureMutex);
  if (finished.load(std::memory_order_relaxed) && block < blocks.size() &&
      unlink("/tmp/metal-frame-interval-repeat") == 0) {
   count = 0; seriesBlocks = 0;
   finished.store(false, std::memory_order_relaxed);
  }
 }
 std::lock_guard<std::mutex> guard(captureMutex);
 if (finished.load(std::memory_order_relaxed)) return nullptr;
 static const int64_t start = presentIntervalNow();
 const int64_t now = presentIntervalNow();
 if (!testing && now - start < 90000000000LL) return nullptr;
 auto& samples = blocks[block];
 static const size_t limit = testing ? 8 : samples.size();
 if (count < limit) { samples[count].queued.store(now); return &samples[count++]; }
 // Completion columns may still be zero; the analyzer labels incomplete rows.
 // Queued timestamps already cover every request in the bounded block.
 char path[96];
 if (block == 0) snprintf(path,sizeof(path),"/tmp/metal-present-intervals.csv");
 else snprintf(path,sizeof(path),"/tmp/metal-present-intervals-%u.csv",block);
 if (FILE* log=fopen(path,"w")) {
  fprintf(log,"queued_ns,render_start_ns,render_done_ns,flush_done_ns\n");
  for (size_t i=0;i<limit;++i) { const auto& sample=samples[i]; fprintf(log,"%lld,%lld,%lld,%lld\n",(long long)sample.queued.load(),(long long)sample.renderStart.load(),(long long)sample.renderDone.load(),(long long)sample.flushDone.load()); }
  fclose(log);
 }
 ++block;
 if (++seriesBlocks >= 8 || block >= blocks.size()) { finished.store(true, std::memory_order_relaxed); return nullptr; }
 count=0;
 // This request covers file I/O and is deliberately outside both sample blocks.
 return nullptr;
}
}

@implementation CAMetalLayerInternal

#if DARLING_METAL_ENABLED

@synthesize presentsWithTransaction = _presentsWithTransaction;
@synthesize displaySyncEnabled = _displaySyncEnabled;
@synthesize wantsExtendedDynamicRangeContent = _wantsExtendedDynamicRangeContent;
@synthesize EDRMetadata = _EDRMetadata;
@synthesize allowsNextDrawableTimeout = _allowsNextDrawableTimeout;
@synthesize developerHUDProperties = _developerHUDProperties;

// TODO: use CGL here instead of direct OpenGL calls
//       (once we CGL-ify the rest of QuartzCore)

- (instancetype)init
{
	self = [super init];
	if (self != nil) {
		_pixelFormat = MTLPixelFormatBGRA8Unorm;
		_framebufferOnly = YES;
		_drawableSize = _bounds.size; // TODO: multiply by contentsScale, once we add that to CALayer
		_displaySyncEnabled = YES;
		_maximumDrawableCount = 3;
		_allowsNextDrawableTimeout = YES;
		_developerHUDProperties = [NSDictionary new];

		_drawableCondition = [NSCondition new];
	}
	return self;
}

- (void)dealloc
{
	[_device release];
	if (_colorspace) {
		CGColorSpaceRelease(_colorspace);
	}
	[_EDRMetadata release];
	[_developerHUDProperties release];
	[_drawableCondition release];

	reportGLErrors();
	if (_tex != 0) {
		glDeleteTextures(1, &_tex);
		reportGLErrors();
	}

	[super dealloc];
}

//
// properties
//

- (id<MTLDevice>)device
{
	return [[_device retain] autorelease];
}

- (void)setDevice: (id<MTLDevice>)device
{
	id<MTLDevice> old = _device;
	_device = [device retain];
	[old release];
	[self recreateDrawables];
}

- (id<MTLDevice>)preferredDevice
{
	return [MTLCreateSystemDefaultDevice() autorelease];
}

- (MTLPixelFormat)pixelFormat
{
	return _pixelFormat;
}

- (void)setPixelFormat: (MTLPixelFormat)pixelFormat
{
	_pixelFormat = pixelFormat;
	[self recreateDrawables];
}

- (CGColorSpaceRef)colorspace
{
	// TODO: retain and autorelease this? it's technically an objc object
	return _colorspace;
}

- (void)setColorspace: (CGColorSpaceRef)colorspace
{
	CGColorSpaceRef old = _colorspace;
	_colorspace = CGColorSpaceRetain(colorspace);
	if (old) {
		CGColorSpaceRelease(old);
	}
}

- (BOOL)framebufferOnly
{
	return _framebufferOnly;
}

- (void)setFramebufferOnly: (BOOL)framebufferOnly
{
	_framebufferOnly = framebufferOnly;
	[self recreateDrawables];
}

- (CGSize)drawableSize
{
	return _drawableSize;
}

- (void)setDrawableSize: (CGSize)drawableSize
{
	_drawableSize = drawableSize;
	[self recreateDrawables];
}

- (NSUInteger)maximumDrawableCount
{
	return _maximumDrawableCount;
}

- (void)setMaximumDrawableCount: (NSUInteger)maximumDrawableCount
{
	if (maximumDrawableCount < 2 || maximumDrawableCount > 3) {
		@throw [NSException exceptionWithName: NSInvalidArgumentException reason: @"Attempt to set maximumDrawableCount to an invalid value" userInfo: nil];
	}
	_maximumDrawableCount = maximumDrawableCount;
	[self recreateDrawables];
}

//
// overridden properties
//

// it appears that the drawable size does NOT change after initially being set
#if 0
- (void)setBounds: (CGRect)value
{
	[super setBounds: value];

	CGSize drawableSize = value.size;
	// TODO: multiply by contentsScale (CALayer doesn't currently have that property)

	[self setDrawableSize: drawableSize];
}
#endif

//
// methods
//

- (id<CAMetalDrawable>)nextDrawable
{
	std::shared_ptr<CAMetalDrawableActual> drawable = nullptr;
	CFTimeInterval waitStart = CACurrentMediaTime();

	[_drawableCondition lock];

	NSDate* endTime = [NSDate dateWithTimeIntervalSinceNow: 1];

	while (_usableDrawablesBitmap == 0) {
		// No drawable is free: this thread really blocks here (the wait is what the pool starvation costs the game).
		Indium::Waits::Block block("nextDrawable");
		if ([NSThread isMainThread]) {
			if (_queuedDrawableCount > 0 && self->_context) {
				[_drawableCondition unlock];
				[self->_context render];
				[self->_context flush];
				[_drawableCondition lock];
				if (_usableDrawablesBitmap != 0) break;
			}
			[_drawableCondition unlock];
			CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.001, YES);
			[_drawableCondition lock];
			if (_usableDrawablesBitmap != 0) break;
			if (CACurrentMediaTime() >= waitStart + 1.0) break;
		} else {
			if (_allowsNextDrawableTimeout) {
				if (![_drawableCondition waitUntilDate: endTime]) {
					break;
				}
			} else {
				[_drawableCondition wait];
			}
		}
	}

	if (_usableDrawablesBitmap == 0) {
		// timeout reached
		darlingMetalTiming("nextDrawableTimeout", CACurrentMediaTime() - waitStart);
		darlingMetalTrace("nextDrawable-timeout", (long) _queuedDrawableCount, 0);
		[_drawableCondition unlock];
		return nil;
	}

	uint8_t drawableID = UINT8_MAX;

	for (uint8_t i = 0; i < _maximumDrawableCount; ++i) {
		if (_usableDrawablesBitmap & (1u << i)) {
			drawableID = i;
			break;
		}
	}

	if (drawableID == UINT8_MAX) {
		// shouldn't happen, but just in case
		[_drawableCondition unlock];
		return nil;
	}

	_usableDrawablesBitmap &= ~(1u << drawableID);
	darlingMetalTiming("nextDrawableWait", CACurrentMediaTime() - waitStart);
	darlingMetalTrace("nextDrawable-ok", (long) drawableID, (long) _usableDrawablesBitmap);

	drawable = _drawables[drawableID];

	[_drawableCondition unlock];

	return [[[CAMetalDrawableInternal alloc] initWithLayer: self drawable: drawable] autorelease];
}

- (void)queuePresent: (NSUInteger)drawableID
{
    auto* intervalSample = beginPresentIntervalSample();
	[_drawableCondition lock];
	_queuedDrawables[_queuedDrawableCount] = drawableID;
	++_queuedDrawableCount;
	darlingMetalTrace("queuePresent", (long) drawableID, (long) _queuedDrawableCount);
	[_drawableCondition unlock];

	// we now need to schedule a render
	//
	// FIXME: once we fix up CALayer and make it more featureful, this needs to change to `self.needsDisplay = YES` or equivalently `[self setNeedsDisplay: YES]`
	// right now, CALayer is missing all the needs-display logic (which is currently in NSView)
    // Present only after the Vulkan/GL synchronization has been prepared, on
    // the window thread. display alone does not drive the layer compositor.
    void (^renderBlock)(void) = ^{
        if (intervalSample) intervalSample->renderStart.store(presentIntervalNow());
        darlingMetalTrace("present-block-runs", 0, 0);
        CFTimeInterval blockStart = CACurrentMediaTime();
        [self->_context render];
        if (intervalSample) intervalSample->renderDone.store(presentIntervalNow());
        CFTimeInterval renderDone = CACurrentMediaTime();
        darlingMetalTiming("mainBlockRender", renderDone - blockStart);
        [self->_context flush];
        if (intervalSample) intervalSample->flushDone.store(presentIntervalNow(), std::memory_order_release);
        darlingMetalTiming("mainBlockFlush", CACurrentMediaTime() - renderDone);
    };

    if ([NSThread isMainThread]) {
        renderBlock();
    } else {
        dispatch_async(dispatch_get_main_queue(), renderBlock);
    }
}

- (void)releaseDrawable: (NSUInteger)drawableID
{
	darlingMetalTrace("releaseDrawable", (long) drawableID, 0);
	[_drawableCondition lock];
	_usableDrawablesBitmap |= 1u << drawableID;
	[_drawableCondition signal];
	[_drawableCondition unlock];
}

- (void)recreateDrawables
{
	[_drawableCondition lock];

	// drop all queued presentations
	for (NSUInteger i = 0; i < _queuedDrawableCount; ++i) {
		auto& drawable = _drawables[_queuedDrawables[i]];

		// disown it first so it doesn't try to release itself
		// (and end up deadlocking in `releaseDrawable:`)
		drawable->disown();

		drawable->didDrop();
	}
	_queuedDrawableCount = 0;

	// clear the drawable array (and disown them so they don't try to queue with us anymore)
	for (auto& drawable: _drawables) {
		if (drawable) {
			drawable->disown();
		}
		drawable = nullptr;
	}
	_usableDrawablesBitmap = 0;

	if (!_device || !_context || !_context.glContext || _drawableSize.width == 0 || _drawableSize.height == 0) {
		// can't create new drawables
		[_drawableCondition unlock];
		return;
	}

	Indium::PixelFormat pixelFormat;

	switch (_pixelFormat) {
		case MTLPixelFormatBGRA8Unorm:      pixelFormat = Indium::PixelFormat::BGRA8Unorm;      break;
		case MTLPixelFormatBGRA8Unorm_sRGB: pixelFormat = Indium::PixelFormat::BGRA8Unorm_sRGB; break;
		case MTLPixelFormatRGBA16Float:     pixelFormat = Indium::PixelFormat::RGBA16Float;     break;
		case MTLPixelFormatRGB10A2Unorm:    pixelFormat = Indium::PixelFormat::RGB10A2Unorm;    break;
		case MTLPixelFormatBGR10A2Unorm:    pixelFormat = Indium::PixelFormat::BGR10A2Unorm;    break;
		case MTLPixelFormatBGRA10_XR:       pixelFormat = Indium::PixelFormat::BGRA10_XR;       break;
		case MTLPixelFormatBGRA10_XR_sRGB:  pixelFormat = Indium::PixelFormat::BGRA10_XR_sRGB;  break;
		case MTLPixelFormatBGR10_XR:        pixelFormat = Indium::PixelFormat::BGR10_XR;        break;
		case MTLPixelFormatBGR10_XR_sRGB:   pixelFormat = Indium::PixelFormat::BGR10_XR_sRGB;   break;
		default:                            pixelFormat = Indium::PixelFormat::Invalid;         break;
	}

	CGLContextObj prev = CGLGetCurrentContext();
	CGLSetCurrentContext(_context.glContext);

	// now let's start creating the new drawables
	for (size_t i = 0; i < _maximumDrawableCount; ++i) {
		_drawables[i] = std::make_shared<CAMetalDrawableActual>(self, _drawableSize, i, pixelFormat, ((MTLDeviceInternal*)self.device).device, _context.glContext);
		_usableDrawablesBitmap |= 1u << i;
	}

	// now signal the right number of waiters
	for (size_t i = 0; i < _maximumDrawableCount; ++i) {
		[_drawableCondition signal];
	}

	[_drawableCondition unlock];

	@synchronized(self) {
		// resize the render texture
		if (_tex != 0) {
			reportGLErrors();
			glDeleteTextures(1, &_tex);
			reportGLErrors();
			glCreateTextures(GL_TEXTURE_2D, 1, &_tex);
			reportGLErrors();
			glTextureStorage2D(_tex, 1, GL_RGBA8, _drawableSize.width, _drawableSize.height);
			reportGLErrors();
			glTextureParameteri(_tex, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
			glTextureParameteri(_tex, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
			glTextureParameteri(_tex, GL_TEXTURE_WRAP_S, GL_REPEAT);
			glTextureParameteri(_tex, GL_TEXTURE_WRAP_T, GL_REPEAT);
			// The layer is opaque, as on macOS: never let the drawable's alpha reach the compositor (its blending and
			// alpha test turned the game's low-alpha effect regions into black quads). The drawable is copied in with
			// glCopyImageSubData, so the swizzle has to be on this texture, the one that is actually sampled.
			glTextureParameteri(_tex, GL_TEXTURE_SWIZZLE_A, GL_ONE);
			reportGLErrors();
		}
	}

	CGLSetCurrentContext(prev);
}

- (void)prepareRender
{
	std::shared_ptr<CAMetalDrawableActual> drawable = nullptr;
	static CFTimeInterval lastPrepare = 0;
	CFTimeInterval prepareStart = CACurrentMediaTime();
	if (lastPrepare != 0) darlingMetalTiming("prepareRenderInterval", prepareStart - lastPrepare);
	lastPrepare = prepareStart;

	[_drawableCondition lock];
	if (_queuedDrawableCount > 0) {
		drawable = _drawables[_queuedDrawables[0]];
		--_queuedDrawableCount;
		std::copy(_queuedDrawables.begin() + 1, _queuedDrawables.end(), _queuedDrawables.begin());
	}
	[_drawableCondition unlock];

	if (drawable) {
		// wait for the drawable to be fully rendered before copying it to the render texture
		// (this is a GPU-side wait)
		CFTimeInterval syncStart = CACurrentMediaTime();
		drawable->synchronizeRender();
		darlingMetalTiming("synchronizeRender", CACurrentMediaTime() - syncStart);

		reportGLErrors();
		{
			// Diagnostic: statistics of the imported Vulkan image itself, before the copy
			static unsigned long sourceCounter = 0;
			if (darlingMetalDebug() && access("/tmp/metal-debug-frames", F_OK) == 0 && (++sourceCounter <= 30 || sourceCounter % 150 == 0)) {
				size_t width = _drawableSize.width, height = _drawableSize.height;
				std::vector<uint8_t> source(width * height * 4);
				glGetTextureImage(drawable->texture()->glTexture(), 0, GL_RGBA, GL_UNSIGNED_BYTE, (GLsizei) source.size(), source.data());
				unsigned long lit = 0, total = 0;
				for (size_t i = 0; i < source.size(); i += 4) {
					unsigned v = source[i] + source[i + 1] + source[i + 2];
					total += v;
					if (v > 6) ++lit;
				}
				darlingMetalTrace("source-stats", (long) lit, (long) (total / (width * height)));
			}
		}
		reportGLErrors();
		glCopyImageSubData(drawable->texture()->glTexture(), GL_TEXTURE_2D, 0, 0, 0, 0, _tex, GL_TEXTURE_2D, 0, 0, 0, 0, _drawableSize.width, _drawableSize.height, 1);
		reportGLErrors();

		// Diagnostic: every 150th presented frame, log pixel statistics of what is about to be shown
		// and save a few of them as /tmp/metal-frame-<n>.ppm.
		static unsigned long frameCounter = 0;
		++frameCounter;
		if (darlingMetalDebug() && access("/tmp/metal-debug-frames", F_OK) == 0 && (frameCounter <= 30 || frameCounter % 150 == 0) && frameCounter <= 1800) {
			size_t width = _drawableSize.width, height = _drawableSize.height;
			std::vector<uint8_t> pixels(width * height * 4);
			glGetTextureImage(_tex, 0, GL_RGBA, GL_UNSIGNED_BYTE, (GLsizei) pixels.size(), pixels.data());
			unsigned long nonBlack = 0, sum = 0;
			for (size_t i = 0; i < pixels.size(); i += 4) {
				unsigned v = pixels[i] + pixels[i + 1] + pixels[i + 2];
				sum += v;
				if (v > 6) ++nonBlack;
			}
			darlingMetalTrace("frame-stats", (long) nonBlack, (long) (sum / (width * height)));
			if (frameCounter == 5 || frameCounter == 30 || frameCounter == 300 || frameCounter == 900) {
				char path[64];
				snprintf(path, sizeof(path), "/tmp/metal-frame-%lu.ppm", frameCounter);
				if (FILE* out = fopen(path, "wb")) {
					fprintf(out, "P6\n%zu %zu\n255\n", width, height);
					for (size_t row = 0; row < height; ++row) {
						// GL rows run bottom to top
						const uint8_t* line = pixels.data() + (height - 1 - row) * width * 4;
						for (size_t x = 0; x < width; ++x) {
							fwrite(line + x * 4, 1, 3, out);
						}
					}
					fclose(out);
				}
			}
		}
	}

	@synchronized(self) {
		// FIXME: this is wrong, but there's no good way to tell when the texture is actually fully rendered/presented.
		//        this is at least close enough. it should balance out in the long run since we're supposed to be invoked on vsync
		//        or at least a fixed interval.
		if (_lastPresentedDrawable) {
			_lastPresentedDrawable->didPresent();
		}
		_lastPresentedDrawable = drawable;
	}
}

- (NSNumber*)_textureId
{
	return [NSNumber numberWithUnsignedInt: _tex];
}

//
// overridden methods
//

- (void)removeFromSuperlayer
{
	// we're being removed from our superlayer, so we probably won't be rendered again for a while
	//
	// FIXME: if we're the layer for a root view, this won't be called (i think) so we'll just be leaked.
	//        we'll probably have to add another private method to be called when the layer is released externally (e.g. by the layer context).
	@synchronized(self) {
		if (_lastPresentedDrawable) {
			// no way to tell if it was actually presented or not, so assume it was dropped
			_lastPresentedDrawable->didDrop();
			_lastPresentedDrawable = nullptr;
		}
	}
	[super removeFromSuperlayer];
}

- (void)_setContext: (CALayerContext*)context
{
	[super _setContext: context];

    if (!context || !context.glContext) {
        [self recreateDrawables];
        return;
    }

	if (_tex == 0) {
		// create our textures now using the context's CGLContext
		CGLContextObj prev = CGLGetCurrentContext();
		CGLSetCurrentContext(context.glContext);

		reportGLErrors();
		glCreateTextures(GL_TEXTURE_2D, 1, &_tex);
		reportGLErrors();
		glTextureStorage2D(_tex, 1, GL_RGBA8, _drawableSize.width, _drawableSize.height);
		reportGLErrors();
		glTextureParameteri(_tex, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
		glTextureParameteri(_tex, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
		glTextureParameteri(_tex, GL_TEXTURE_WRAP_S, GL_REPEAT);
		glTextureParameteri(_tex, GL_TEXTURE_WRAP_T, GL_REPEAT);
			// The layer is opaque, as on macOS: never let the drawable's alpha reach the compositor (its blending and
			// alpha test turned the game's low-alpha effect regions into black quads). The drawable is copied in with
			// glCopyImageSubData, so the swizzle has to be on this texture, the one that is actually sampled.
			glTextureParameteri(_tex, GL_TEXTURE_SWIZZLE_A, GL_ONE);
		reportGLErrors();

		CGLSetCurrentContext(prev);
	}
    [self recreateDrawables];
}

#else

MTL_UNSUPPORTED_CLASS

#endif

@end
