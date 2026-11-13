/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Developers

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 Darling is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with Darling.  If not, see <http://www.gnu.org/licenses/>.
*/

#import <QuartzCore/CAMetalDisplayLink.h>
#import <QuartzCore/CAMetalLayer.h>

// No display timing exists behind it: the link keeps its run loop modes and
// properties and never calls its delegate. The defaults the documentation
// omits are a GUESS (rung 6): not paused, a zero frame rate range and a zero
// latency.
@implementation CAMetalDisplayLink {
    CAMetalLayer *_layer;
    NSMutableSet *_registrations;
    CAFrameRateRange _preferredFrameRateRange;
    float _preferredFrameLatency;
    id<CAMetalDisplayLinkDelegate> _delegate;
    BOOL _paused;
}

@synthesize preferredFrameRateRange = _preferredFrameRateRange;
@synthesize preferredFrameLatency = _preferredFrameLatency;
@synthesize delegate = _delegate;
@synthesize paused = _paused;

- (instancetype) initWithMetalLayer: (CAMetalLayer *) layer {
    if ((self = [super init]) != nil) {
        _layer = [layer retain];
        _registrations = [[NSMutableSet alloc] init];
    }
    return self;
}

- (void) addToRunLoop: (NSRunLoop *) runloop forMode: (NSRunLoopMode) mode {
    [_registrations addObject: @[ runloop, mode ]];
}

- (void) removeFromRunLoop: (NSRunLoop *) runloop forMode: (NSRunLoopMode) mode {
    [_registrations removeObject: @[ runloop, mode ]];
}

- (void) invalidate {
    [_registrations removeAllObjects];
}

- (void) dealloc {
    [_layer release];
    [_registrations release];
    [super dealloc];
}

@end
