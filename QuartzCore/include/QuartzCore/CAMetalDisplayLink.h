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

#import <Foundation/Foundation.h>
#import <QuartzCore/CAFrameRateRange.h>

@class CAMetalLayer, CAMetalDisplayLink, CAMetalDisplayLinkUpdate;

// The page names the delegate protocol and its purpose; its method was not
// recorded, so it declares none (GUESS, rung 6).
@protocol CAMetalDisplayLinkDelegate <NSObject>
@end

// Documented at developer.apple.com/documentation/quartzcore/cametaldisplaylink
@interface CAMetalDisplayLink : NSObject

- (instancetype) initWithMetalLayer: (CAMetalLayer *) layer;

@property(nonatomic) CAFrameRateRange preferredFrameRateRange;
@property(nonatomic) float preferredFrameLatency;
@property(nonatomic, weak, nullable) id<CAMetalDisplayLinkDelegate> delegate;
@property(nonatomic, getter=isPaused) BOOL paused;

- (void) addToRunLoop: (NSRunLoop *) runloop forMode: (NSRunLoopMode) mode;
- (void) removeFromRunLoop: (NSRunLoop *) runloop forMode: (NSRunLoopMode) mode;
- (void) invalidate;

@end
