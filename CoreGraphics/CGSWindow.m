/*
 This file is part of Darling.

 Copyright (C) 2020 Lubos Dolezel

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
#import <CoreGraphics/CGSConnection.h>
#import <CoreGraphics/CGSWindow.h>
#import <Foundation/NSRaise.h>

const CFStringRef kCGSWindowTitle = CFSTR("WindowTitle");

@implementation CGSWindow
@synthesize windowId = _windowId;

- (instancetype) initWithRegion: (CGSRegionRef) region
                     connection: (CGSConnection *) connection
                       windowID: (CGSWindowID) windowID
{
    _connection = connection;
    _nextSurfaceId = 1;
    _surfaces = [[NSMutableDictionary alloc] initWithCapacity: 1];
    _windowId = windowID;
    return self;
}

- (void) dealloc {
    [_surfaces release];
    [super dealloc];
}

- (CGSSurface *) surfaceForId: (CGSSurfaceID) surfaceId {
    CGSSurface *rv;
    @synchronized(_surfaces) {
        rv = [_surfaces objectForKey: [NSNumber numberWithInt: surfaceId]];
    }
    return rv;
}

- (void) _surfaceInvalidated: (CGSSurfaceID) surfaceId {
    @synchronized(_surfaces) {
        [_surfaces removeObjectForKey: [NSNumber numberWithInt: surfaceId]];
    }
}

- (void) invalidate {
    [_connection _windowInvalidated: _windowId];
}

- (CGError) orderWindow: (CGSWindowOrderingMode) place
             relativeTo: (CGSWindow *) window
{
    NSInvalidAbstractInvocation();
}

- (CGError) moveTo: (const CGPoint *) point {
    NSInvalidAbstractInvocation();
}

- (CGError) setRegion: (CGSRegionRef) region {
    NSInvalidAbstractInvocation();
}

- (CGError) getRect: (CGRect *) outRect {
    NSInvalidAbstractInvocation();
}

- (CGError) setProperty: (CFStringRef) key value: (CFTypeRef) value {
    NSInvalidAbstractInvocation();
}

- (CGError) getProperty: (CFStringRef) key value: (CFTypeRef *) value {
    NSInvalidAbstractInvocation();
}

- (CGSSurface *) createSurface {
    NSInvalidAbstractInvocation();
}

- (void *) nativeWindow {
    NSInvalidAbstractInvocation();
}

@end

CGError CGSSetWindowTitle(CGSConnectionID cid, CGSWindowID wid,
                          CFStringRef title)
{
    return CGSSetWindowProperty(cid, wid, kCGSWindowTitle, title);
}

// Windows of every client of the display server, front to back. The option and the reference
// window select the same subsets as on macOS.
CFArrayRef __nullable CGWindowListCopyWindowInfo(CGWindowListOption option, CGWindowID relativeToWindow)
{
	CGSConnection* connection = _CGSConnectionForID(_CGSDefaultConnection());
	NSArray<NSDictionary*>* all = connection ? [connection copyWindowDescriptions] : [[NSArray alloc] init];
	NSMutableArray<NSDictionary*>* selected = [[NSMutableArray alloc] init];

	NSInteger referenceIndex = NSNotFound;
	for (NSUInteger i = 0; i < [all count]; i++)
	{
		if ([all[i][(NSString*) kCGWindowNumber] unsignedIntValue] == relativeToWindow)
			referenceIndex = i;
	}

	for (NSUInteger i = 0; i < [all count]; i++)
	{
		NSDictionary* window = all[i];
		BOOL isReference = (NSInteger) i == referenceIndex;
		BOOL haveReference = referenceIndex != NSNotFound;
		BOOL include = YES;

		if ((option & kCGWindowListOptionOnScreenOnly) && ![window[(NSString*) kCGWindowIsOnscreen] boolValue])
			continue;

		// The list is front to back: earlier entries are above the reference window
		if (option & kCGWindowListOptionOnScreenAboveWindow)
			include = (haveReference && (NSInteger) i < referenceIndex) || ((option & kCGWindowListOptionIncludingWindow) && isReference);
		else if (option & kCGWindowListOptionOnScreenBelowWindow)
			include = (haveReference && (NSInteger) i > referenceIndex) || ((option & kCGWindowListOptionIncludingWindow) && isReference);
		else if (option & kCGWindowListOptionIncludingWindow)
			include = isReference;

		if (include)
			[selected addObject: window];
	}

	[all release];
	return (CFArrayRef) selected;
}

CFArrayRef __nullable CGWindowListCreate(CGWindowListOption option, CGWindowID relativeToWindow)
{
    printf("STUB %s\n", __PRETTY_FUNCTION__);
    return nil;
}

CGImageRef __nullable CGWindowListCreateImage(CGRect screenBounds,
                                              CGWindowListOption listOption,
                                              CGWindowID windowID,
                                              CGWindowImageOption imageOption)
{
    printf("STUB %s\n", __PRETTY_FUNCTION__);
    return nil;
}

