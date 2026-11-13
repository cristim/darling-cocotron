// The object-ID notification names and NSUpdatedObjectIDsKey are exported by
// CoreData as non-empty, pairwise distinct strings.
#import <CoreData/CoreData.h>
#import <Foundation/Foundation.h>
#include <stdlib.h>

static void expect(BOOL condition, NSString *message)
{
    if (!condition)
    {
        NSLog(@"FAIL: %@", message);
        exit(1);
    }
}

int main(void)
{
    @autoreleasepool
    {
        NSString *names[] = {
            NSManagedObjectContextObjectsDidChangeNotification,
            NSManagedObjectContextDidSaveObjectIDsNotification,
            NSManagedObjectContextDidMergeChangesObjectIDsNotification,
            NSUpdatedObjectIDsKey,
            NSManagedObjectContextDidSaveNotification,
            NSUpdatedObjectsKey,
        };
        NSMutableSet *seen = [NSMutableSet set];
        for (size_t i = 0; i < sizeof(names) / sizeof(names[0]); i++)
        {
            expect([names[i] isKindOfClass:[NSString class]] && [names[i] length] > 0,
                   @"constant is a non-empty NSString");
            [seen addObject:names[i]];
        }
        expect([seen count] == 6, @"new names differ from each other and from the existing ones");
        NSLog(@"PASS: object-ID notification names");
    }
    return 0;
}
