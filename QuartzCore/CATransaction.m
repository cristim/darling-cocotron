#import "CATransactionGroup.h"
#import <Foundation/NSArray.h>
#import <Foundation/NSNumber.h>
#import <Foundation/NSString.h>
#import <QuartzCore/CALayerContext.h>
#import <QuartzCore/CATransaction.h>
#import <Block.h>
#import <CoreFoundation/CFRunLoop.h>
#include <stdlib.h>
extern void DarlingCAPublishCommittedIOSurface(void);

NSString *const kCATransactionAnimationDuration =
        @"kCATransactionAnimationDuration";
NSString *const kCATransactionDisableActions = @"kCATransactionDisableActions";
NSString *const kCATransactionAnimationTimingFunction =
        @"kCATransactionAnimationTimingFunction";
NSString *const kCATransactionCompletionBlock =
        @"kCATransactionCompletionBlock";

@implementation CATransaction

/* Commit callbacks belong to the registering thread, and are consumed once. */
typedef struct CommitHandler {
    void (^block)(void);
    CATransactionPhase phase;
    struct CommitHandler *next;
} CommitHandler;
static __thread CommitHandler *pendingCommitHandlers;
static __thread BOOL commitHandlersScheduled;
static __thread BOOL drainingCommitHandlers;
static __thread CATransactionGroup *implicitTransactionGroup;
static CATransactionGroup *createImplicitTransactionGroupIfNeeded(void);

+ (void) addCommitHandler: (void (^)(void)) handler
                 forPhase: (CATransactionPhase) phase {
    if (!handler || phase < 0 || phase > 2)
        return;
    createImplicitTransactionGroupIfNeeded();
    CommitHandler *entry = calloc(1, sizeof(*entry));
    if (!entry)
        return;
    entry->block = Block_copy(handler);
    entry->phase = phase;
    CommitHandler **tail = &pendingCommitHandlers;
    while (*tail)
        tail = &(*tail)->next;
    *tail = entry;
}

+ (void) _drainCommitHandlers {
    CommitHandler *batch = pendingCommitHandlers;
    pendingCommitHandlers = NULL;
    commitHandlersScheduled = NO;
    drainingCommitHandlers = YES;
    for (int phase = 0; phase < 3; ++phase)
        for (CommitHandler *entry = batch; entry; entry = entry->next)
            if (entry->phase == phase)
                entry->block();
    while (batch) {
        CommitHandler *next = batch->next;
        Block_release(batch->block);
        free(batch);
        batch = next;
    }
    drainingCommitHandlers = NO;
    [self _scheduleCommitHandlers];
}

+ (void) setCompletionBlock: (void (^)(void)) block {
    void (^copy)(void) = block ? Block_copy(block) : nil;
    [self setValue: (id)copy forKey: kCATransactionCompletionBlock];
    if (copy) Block_release(copy);
}

+ (void (^)(void)) completionBlock {
    return [self valueForKey: kCATransactionCompletionBlock];
}

static NSMutableArray *transactionStack() {
    NSMutableDictionary *shared = [NSCurrentThread() sharedDictionary];
    id stack = [shared objectForKey: @"CATransactionStack"];

    if (stack == nil) {
        stack = [NSMutableArray array];
        [shared setObject: stack forKey: @"CATransactionStack"];
    }

    return stack;
}

static CATransactionGroup *currentTransactionGroup() {
    id stack = transactionStack();

    CATransactionGroup *result = [stack lastObject];

    return result;
}

static CATransactionGroup *createImplicitTransactionGroupIfNeeded() {
    CATransactionGroup *check = currentTransactionGroup();

    if (check == nil) {
        check = [[CATransactionGroup alloc] init];

        [transactionStack() addObject: check];
        implicitTransactionGroup = check;
        [check release];
        [[NSRunLoop currentRunLoop]
                performSelector: @selector(_commitImplicitTransaction)
                         target: [CATransaction class]
                       argument: nil
                          order: 0
                          modes: [NSArray arrayWithObject:
                                                  NSDefaultRunLoopMode]];
    }

    return check;
}

+ (BOOL) disableActions {
    return [[self valueForKey: kCATransactionDisableActions] boolValue];
}

+ (CFTimeInterval) animationDuration {
    return [[self valueForKey: kCATransactionAnimationDuration] doubleValue];
}

+ (CAMediaTimingFunction *) animationTimingFunction {
    return [self valueForKey: kCATransactionAnimationTimingFunction];
}

//+(void (^)(void))completionBlock;

+ valueForKey: (NSString *) key {
    CATransactionGroup *group = createImplicitTransactionGroupIfNeeded();

    return [group valueForKey: key];
}

+ (void) setAnimationDuration: (CFTimeInterval) value {
    [self setValue: [NSNumber numberWithDouble: value]
            forKey: kCATransactionAnimationDuration];
}

+ (void) setAnimationTimingFunction: (CAMediaTimingFunction *) value {
    [self setValue: value forKey: kCATransactionAnimationDuration];
}

//+(void)setCompletionBlock:(void (^)(void))value;
+ (void) setDisableActions: (BOOL) value {
    [self setValue: [NSNumber numberWithBool: value]
            forKey: kCATransactionDisableActions];
}

+ (void) setValue: value forKey: (NSString *) key {
    CATransactionGroup *group = createImplicitTransactionGroupIfNeeded();

    [group setValue: value forKey: key];
}

+ (void) begin {
    CATransactionGroup *group = [[CATransactionGroup alloc] init];

    [transactionStack() addObject: group];
    [group release];
}

+ (void) _scheduleCommitHandlers {
    if ([transactionStack() count] || !pendingCommitHandlers ||
        commitHandlersScheduled || drainingCommitHandlers)
        return;
    /* Chromium's handlers may pump a nested runloop. Invoke them after the
     * transaction has unwound, on its original thread. Drain new batches
     * only after the current batch has completed all of its phases. */
    commitHandlersScheduled = YES;
    CFRunLoopRef loop = CFRunLoopGetCurrent();
    CFRunLoopPerformBlock(loop, kCFRunLoopCommonModes, ^{
        [CATransaction _drainCommitHandlers];
    });
    CFRunLoopWakeUp(loop);
}

+ (void) _commitImplicitTransaction {
    NSMutableArray *stack = transactionStack();
    if ([stack count] == 1 && [stack lastObject] == implicitTransactionGroup)
        [self commit];
}

+ (void) commit {
    NSMutableArray *stack = transactionStack();
    if ([stack count]) {
        void (^completion)(void) = [[stack lastObject] valueForKey: kCATransactionCompletionBlock];
        if (completion)
            [self addCommitHandler: completion forPhase: kCATransactionPhasePostCommit];
        if ([stack lastObject] == implicitTransactionGroup)
            implicitTransactionGroup = nil;
        [stack removeLastObject];
    }
    if ([stack count] == 1 && [stack lastObject] == implicitTransactionGroup) {
        CFRunLoopRef loop = CFRunLoopGetCurrent();
        CFRunLoopPerformBlock(loop, kCFRunLoopCommonModes, ^{
            [CATransaction _commitImplicitTransaction];
        });
        CFRunLoopWakeUp(loop);
    }
    if (![stack count])
        DarlingCAPublishCommittedIOSurface();
    [self _scheduleCommitHandlers];
}

+ (void) flush {
    NSMutableArray *stack = transactionStack();
    BOOL commitsImplicit = [stack count] == 1 && [stack lastObject] == implicitTransactionGroup;
    [self _commitImplicitTransaction];
    /* An implicit commit already publishes its completed frame. */
    if(!getenv("DARLING_CA_PRESENT_AT_COMMIT") || !commitsImplicit)
        DarlingCAPublishCommittedIOSurface();
}

+ (void) lock {
}

+ (void) unlock {
}

@end
