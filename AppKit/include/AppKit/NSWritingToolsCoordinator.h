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

#import <AppKit/AppKitExport.h>
#import <Foundation/Foundation.h>

@class NSView, NSWritingToolsCoordinatorContext;
@protocol NSWritingToolsCoordinatorDelegate;

// The constant names below are documented under
// developer.apple.com/documentation/appkit/nswritingtoolscoordinator and
// nswritingtoolsbehavior / nswritingtoolsresultoptions; the documentation
// gives no values, so all of them are a GUESS (rung 6).
typedef NS_ENUM(NSInteger, NSWritingToolsBehavior) {
    NSWritingToolsBehaviorNone = -1,
    NSWritingToolsBehaviorDefault = 0,
    NSWritingToolsBehaviorComplete = 1,
    NSWritingToolsBehaviorLimited = 2,
};

typedef NS_OPTIONS(NSUInteger, NSWritingToolsResultOptions) {
    NSWritingToolsResultDefault = 0,
    NSWritingToolsResultPlainText = 1 << 0,
    NSWritingToolsResultRichText = 1 << 1,
    NSWritingToolsResultList = 1 << 2,
    NSWritingToolsResultTable = 1 << 3,
    NSWritingToolsResultPresentationIntent = 1 << 4,
};

typedef NS_ENUM(NSInteger, NSWritingToolsCoordinatorState) {
    NSWritingToolsCoordinatorStateInactive = 0,
    NSWritingToolsCoordinatorStateNoninteractive,
    NSWritingToolsCoordinatorStateInteractiveResting,
    NSWritingToolsCoordinatorStateInteractiveStreaming,
};

typedef NS_ENUM(NSInteger, NSWritingToolsCoordinatorTextUpdateReason) {
    NSWritingToolsCoordinatorTextUpdateReasonTyping = 0,
    NSWritingToolsCoordinatorTextUpdateReasonUndoRedo,
};

typedef NS_ENUM(NSInteger, NSWritingToolsCoordinatorTextAnimation) {
    NSWritingToolsCoordinatorTextAnimationAnticipate = 0,
    NSWritingToolsCoordinatorTextAnimationInsert,
    NSWritingToolsCoordinatorTextAnimationRemove,
    NSWritingToolsCoordinatorTextAnimationAnticipateInactive,
    NSWritingToolsCoordinatorTextAnimationTranslate,
    NSWritingToolsCoordinatorTextAnimationIndicateGrammar,
};

// The page names the delegate protocol and its purpose; its members were not
// recorded, so it declares none (GUESS, rung 6).
@protocol NSWritingToolsCoordinatorDelegate <NSObject>
@end

// Documented at developer.apple.com/documentation/appkit/nswritingtoolscoordinator
@interface NSWritingToolsCoordinator : NSObject

- (instancetype) initWithDelegate: (id<NSWritingToolsCoordinatorDelegate>) delegate;

@property(class, readonly) BOOL isWritingToolsAvailable;
@property(weak, readonly, nullable) id<NSWritingToolsCoordinatorDelegate> delegate;
@property(weak, readonly, nullable) NSView *view;
@property(weak, nullable) NSView *effectContainerView;
@property(weak, nullable) NSView *decorationContainerView;
@property NSWritingToolsBehavior preferredBehavior;
@property(readonly) NSWritingToolsBehavior behavior;
@property NSWritingToolsResultOptions preferredResultOptions;
@property(readonly) NSWritingToolsResultOptions resultOptions;
@property BOOL includesTextListMarkers;
@property(readonly) NSWritingToolsCoordinatorState state;

- (void) updateRange: (NSRange) range
            withText: (NSAttributedString *) replacementText
              reason: (NSWritingToolsCoordinatorTextUpdateReason) reason
forContextWithIdentifier: (NSUUID *) contextID;
- (void) updateForReflowedTextInContextWithIdentifier: (NSUUID *) contextID;
- (void) stopWritingTools;
- (NSUUID *) startTextAnimation: (NSWritingToolsCoordinatorTextAnimation) textAnimation
                       forRange: (NSRange) range
                      inContext: (NSWritingToolsCoordinatorContext *) context
               writingDirection: (NSWritingDirection) writingDirection;
- (BOOL) showGrammarPresentationForRange: (NSRange) range inContext: (NSWritingToolsCoordinatorContext *) context;
- (void) cancelTextAnimationsWithIdentifiers: (NSArray<NSUUID *> *) identifiers;

@end
