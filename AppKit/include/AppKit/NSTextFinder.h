#import <Foundation/NSObject.h>

@protocol NSTextFinderBarContainer <NSObject>

@end

@protocol NSTextFinderClient <NSObject>

@end

@interface NSTextFinder : NSObject {
    id<NSTextFinderClient> _client;
    id<NSTextFinderBarContainer> _findBarContainer;
    BOOL _incrementalSearchingShouldDimContentView;
}

@property(assign) id<NSTextFinderClient> client;
@property(assign) id<NSTextFinderBarContainer> findBarContainer;
@property BOOL incrementalSearchingShouldDimContentView;

@end
