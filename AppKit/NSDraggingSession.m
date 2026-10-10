/*
 This file is part of Darling.

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

#import "NSDraggingSession-Private.h"
#import <AppKit/NSPasteboard.h>

@implementation NSDraggingSession

@synthesize draggingPasteboard = _pasteboard, draggingLocation = _draggingLocation;
@synthesize animatesToStartingPositionsOnCancelOrFail = _animatesToStartingPositionsOnCancelOrFail;
@synthesize draggingFormation = _draggingFormation;

- (instancetype)_initWithPasteboard:(NSPasteboard *)pasteboard
{
    if ((self = [super init]))
    {
        _pasteboard = [pasteboard retain];
        _animatesToStartingPositionsOnCancelOrFail = YES;
        _draggingFormation = NSDraggingFormationDefault;
    }
    return self;
}

- (void)dealloc
{
    [_pasteboard release];
    [super dealloc];
}

- (void)_setDraggingLocation:(NSPoint)location
{
    _draggingLocation = location;
}

@end

@implementation _NSDraggingSourceBridge {
    NSDraggingSession *_session;
    id _source;
    BOOL _began;
}

@synthesize began = _began;

- (instancetype)initWithSession:(NSDraggingSession *)session source:(id)source
{
    if ((self = [super init]))
    {
        _session = [session retain];
        _source = [source retain];
    }
    return self;
}

- (void)dealloc
{
    [_session release];
    [_source release];
    [super dealloc];
}

- (id)_originalDraggingSource
{
    return _source;
}

// A source implementing both generations gets only the session callbacks.
- (NSDragOperation)draggingSourceOperationMaskForLocal:(BOOL)local
{
    if ([_source respondsToSelector:@selector(draggingSession:sourceOperationMaskForDraggingContext:)])
        return [_source draggingSession:_session
            sourceOperationMaskForDraggingContext:local ? NSDraggingContextWithinApplication
                                                         : NSDraggingContextOutsideApplication];
    if ([_source respondsToSelector:@selector(draggingSourceOperationMaskForLocal:)])
        return [_source draggingSourceOperationMaskForLocal:local];
    return NSDragOperationCopy;
}

- (void)draggedImage:(NSImage *)image beganAt:(NSPoint)point
{
    _began = YES;
    [_session _setDraggingLocation:point];
    if ([_source respondsToSelector:@selector(draggingSession:willBeginAtPoint:)])
        [_source draggingSession:_session willBeginAtPoint:point];
    else if ([_source respondsToSelector:@selector(draggedImage:beganAt:)])
        [_source draggedImage:image beganAt:point];
}

- (void)draggedImage:(NSImage *)image endedAt:(NSPoint)point operation:(NSDragOperation)operation
{
    [_session _setDraggingLocation:point];
    if ([_source respondsToSelector:@selector(draggingSession:endedAtPoint:operation:)])
        [_source draggingSession:_session endedAtPoint:point operation:operation];
    else if ([_source respondsToSelector:@selector(draggedImage:endedAt:operation:)])
        [_source draggedImage:image endedAt:point operation:operation];
}

@end
