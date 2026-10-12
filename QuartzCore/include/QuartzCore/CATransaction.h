#import <Foundation/NSObject.h>
#import <QuartzCore/CABase.h>

@class CAMediaTimingFunction;

CA_EXPORT NSString *const kCATransactionAnimationDuration;
CA_EXPORT NSString *const kCATransactionDisableActions;
CA_EXPORT NSString *const kCATransactionAnimationTimingFunction;
CA_EXPORT NSString *const kCATransactionCompletionBlock;

@interface CATransaction : NSObject

/* darling-lol M57: Chromium schedules post-commit work with
 * +[CATransaction addCommitHandler:forPhase:]; Cocotron did not implement it,
 * so the UX aborted with an unrecognized-selector NSException right after
 * createWindow(). The phase constants match macOS. */
typedef NSInteger CATransactionPhase;
enum {
    kCATransactionPhasePreLayout = 0,
    kCATransactionPhasePreCommit = 1,
    kCATransactionPhasePostCommit = 2,
};

+ (void) addCommitHandler: (void (^)(void)) handler
                 forPhase: (CATransactionPhase) phase;

+ (void) setCompletionBlock: (void (^)(void)) block;
+ (void (^)(void)) completionBlock;

+ (BOOL) disableActions;
+ (CFTimeInterval) animationDuration;
+ (CAMediaTimingFunction *) animationTimingFunction;
//+(void (^)(void))completionBlock;
+ valueForKey: (NSString *) key;

+ (void) setAnimationDuration: (CFTimeInterval) value;
+ (void) setAnimationTimingFunction: (CAMediaTimingFunction *) value;
//+(void)setCompletionBlock:(void (^)(void))value;
+ (void) setDisableActions: (BOOL) value;
+ (void) setValue: value forKey: (NSString *) key;

+ (void) begin;
+ (void) commit;
+ (void) flush;

+ (void) lock;
+ (void) unlock;

@end
