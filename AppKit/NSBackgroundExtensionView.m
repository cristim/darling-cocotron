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

#import <AppKit/NSBackgroundExtensionView.h>

// The documentation gives the default of automaticallyPlacesContentView (YES)
// and says the content view becomes a subview. The extension effect and the
// safe-area placement are not implemented, so the content view keeps whatever
// frame it has; that part is a GUESS (rung 6).
@implementation NSBackgroundExtensionView {
    NSView *_contentView;
    BOOL _automaticallyPlacesContentView;
}

@synthesize automaticallyPlacesContentView = _automaticallyPlacesContentView;
@synthesize contentView = _contentView;

- (instancetype) initWithFrame: (NSRect) frame {
    if ((self = [super initWithFrame: frame]) != nil)
        _automaticallyPlacesContentView = YES;
    return self;
}

- (instancetype) initWithCoder: (NSCoder *) coder {
    if ((self = [super initWithCoder: coder]) != nil)
        _automaticallyPlacesContentView = YES;
    return self;
}

- (void) setContentView: (NSView *) contentView {
    if (contentView == _contentView)
        return;
    [_contentView removeFromSuperview];
    [_contentView release];
    _contentView = [contentView retain];
    if (_contentView != nil)
        [self addSubview: _contentView];
}

- (void) dealloc {
    [_contentView release];
    [super dealloc];
}

@end
