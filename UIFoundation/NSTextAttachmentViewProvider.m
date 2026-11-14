/*
 This file is part of Darling.

 Copyright (C) 2026 Darling developers

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

#import "UIFAppKit.h"
#import <AppKit/NSTextAttachment.h>
#import <AppKit/NSTextContainer.h>
#import <AppKit/NSTextRange.h>

// The public documentation gives the interface and says the framework calls -loadView "at the appropriate time"; it
// does not say what the base class does.
//
// GUESS (not in the public documentation, not observed): -loadView does nothing in the base class; the -view getter
// calls it once when no view has been set (as NSViewController does), so a subclass that sets self.view in -loadView
// has a view whenever anyone asks, and code that reads -view before the framework's call (open-source callers read
// view.bounds in attachmentBoundsForAttributes:) does not see a nil that real AppKit would not give; the parent view
// of the initializer is not kept (the documentation exposes no property for it); plain -init raises, because the
// location is not optional and only the designated initializer sets it.
// GUESS (same): the default bounds are the attachment's own bounds when they are not empty, the loaded view's size
// at the origin otherwise. The documentation says only that the bounds come from the provider when
// tracksTextAttachmentViewBounds is YES (default NO).
@implementation NSTextAttachmentViewProvider {
    NSTextAttachment *_textAttachment;         // weak in Apple's header; not retained here, like NSTextKit2.m
    NSTextLayoutManager *_textLayoutManager;   // weak, same
    id<NSTextLocation> _location;
    NSView *_view;
    BOOL _tracksTextAttachmentViewBounds;
    BOOL _loadViewCalled;
}

- (instancetype) init {
    [self release];
    [NSException raise: NSInvalidArgumentException
                format: @"-[NSTextAttachmentViewProvider init]: use initWithTextAttachment:parentView:textLayoutManager:location:"];
    return nil;
}

- (instancetype) initWithTextAttachment: (NSTextAttachment *) textAttachment
                             parentView: (NSView *) parentView
                      textLayoutManager: (NSTextLayoutManager *) textLayoutManager
                               location: (id<NSTextLocation>) location
{
    if ((self = [super init])) {
        _textAttachment = textAttachment;
        _textLayoutManager = textLayoutManager;
        _location = [(id) location retain];
    }
    return self;
}

- (void) dealloc {
    [(id) _location release];
    [_view release];
    [super dealloc];
}

- (NSTextAttachment *) textAttachment {
    return _textAttachment;
}

- (NSTextLayoutManager *) textLayoutManager {
    return _textLayoutManager;
}

- (id<NSTextLocation>) location {
    return _location;
}

- (NSView *) view {
    if (_view == nil && !_loadViewCalled) {
        _loadViewCalled = YES;
        [self loadView];
    }
    return _view;
}

- (void) setView: (NSView *) view {
    [view retain];
    [_view release];
    _view = view;
}

- (BOOL) tracksTextAttachmentViewBounds {
    return _tracksTextAttachmentViewBounds;
}

- (void) setTracksTextAttachmentViewBounds: (BOOL) tracks {
    _tracksTextAttachmentViewBounds = tracks;
}

- (void) loadView {
}

- (CGRect) attachmentBoundsForAttributes: (NSDictionary<NSAttributedStringKey, id> *) attributes
                                location: (id<NSTextLocation>) location
                           textContainer: (NSTextContainer *) textContainer
                    proposedLineFragment: (CGRect) proposedLineFragment
                                position: (CGPoint) position
{
    CGRect bounds = [_textAttachment bounds];
    if (!CGRectIsEmpty(bounds))
        return bounds;
    NSView *view = [self view];
    if (view != nil) {
        NSRect viewBounds = [(id) view bounds];
        return CGRectMake(0, 0, viewBounds.size.width, viewBounds.size.height);
    }
    return CGRectZero;
}

@end
