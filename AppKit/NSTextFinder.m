#import <AppKit/NSTextFinder.h>

@implementation NSTextFinder

- (id<NSTextFinderClient>)client { return _client; }
- (void)setClient:(id<NSTextFinderClient>)client { _client = client; }
- (id<NSTextFinderBarContainer>)findBarContainer { return _findBarContainer; }
- (void)setFindBarContainer:(id<NSTextFinderBarContainer>)container { _findBarContainer = container; }
- (BOOL)incrementalSearchingShouldDimContentView { return _incrementalSearchingShouldDimContentView; }
- (void)setIncrementalSearchingShouldDimContentView:(BOOL)value {
    _incrementalSearchingShouldDimContentView = value;
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector
{
    return [NSMethodSignature signatureWithObjCTypes: "v@:"];
}

- (void)forwardInvocation:(NSInvocation *)anInvocation
{
    NSLog(@"Stub called: %@ in %@", NSStringFromSelector([anInvocation selector]), [self class]);
}

@end
