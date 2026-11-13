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

#import <AppKit/NSWritingToolsCoordinator.h>
#import <AppKit/NSView.h>
#import "NSStubForwarding-Private.h"

// No Writing Tools back end exists, so the class reports it as unavailable,
// stays inactive and logs the first unimplemented action message. The
// defaults the documentation omits are a GUESS (rung 6): the preferred
// behavior is the default one, the effective behavior is none, and the
// preferred result options are the default ones.
@implementation NSWritingToolsCoordinator {
    id<NSWritingToolsCoordinatorDelegate> _delegate;
    NSView *_effectContainerView;
    NSView *_decorationContainerView;
    NSWritingToolsBehavior _preferredBehavior;
    NSWritingToolsResultOptions _preferredResultOptions;
    BOOL _includesTextListMarkers;
}

@synthesize delegate = _delegate;
@synthesize effectContainerView = _effectContainerView;
@synthesize decorationContainerView = _decorationContainerView;
@synthesize preferredBehavior = _preferredBehavior;
@synthesize preferredResultOptions = _preferredResultOptions;
@synthesize includesTextListMarkers = _includesTextListMarkers;

+ (BOOL) isWritingToolsAvailable {
    return NO;
}

- (instancetype) initWithDelegate: (id<NSWritingToolsCoordinatorDelegate>) delegate {
    if ((self = [super init]) != nil) {
        _delegate = delegate;
        _preferredBehavior = NSWritingToolsBehaviorDefault;
        _preferredResultOptions = NSWritingToolsResultDefault;
    }
    return self;
}

- (NSView *) view {
    return nil;
}

- (NSWritingToolsBehavior) behavior {
    return NSWritingToolsBehaviorNone;
}

- (NSWritingToolsResultOptions) resultOptions {
    return NSWritingToolsResultDefault;
}

- (NSWritingToolsCoordinatorState) state {
    return NSWritingToolsCoordinatorStateInactive;
}

- (void) updateRange: (NSRange) range
            withText: (NSAttributedString *) replacementText
              reason: (NSWritingToolsCoordinatorTextUpdateReason) reason
forContextWithIdentifier: (NSUUID *) contextID {
    NSStubLogUnimplementedOnce([self class], _cmd);
}

- (void) updateForReflowedTextInContextWithIdentifier: (NSUUID *) contextID {
    NSStubLogUnimplementedOnce([self class], _cmd);
}

- (void) stopWritingTools {
    NSStubLogUnimplementedOnce([self class], _cmd);
}

- (NSUUID *) startTextAnimation: (NSWritingToolsCoordinatorTextAnimation) textAnimation
                       forRange: (NSRange) range
                      inContext: (NSWritingToolsCoordinatorContext *) context
               writingDirection: (NSWritingDirection) writingDirection {
    NSStubLogUnimplementedOnce([self class], _cmd);
    return nil;
}

- (BOOL) showGrammarPresentationForRange: (NSRange) range inContext: (NSWritingToolsCoordinatorContext *) context {
    NSStubLogUnimplementedOnce([self class], _cmd);
    return NO;
}

- (void) cancelTextAnimationsWithIdentifiers: (NSArray<NSUUID *> *) identifiers {
    NSStubLogUnimplementedOnce([self class], _cmd);
}

@end
