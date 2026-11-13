// NSBatchUpdateRequest is a description only: initialisers keep the entity
// name, the documented defaults hold, and a copy carries every field.
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
        NSBatchUpdateRequest *request = [NSBatchUpdateRequest batchUpdateRequestWithEntityName:@"Note"];
        expect([request isKindOfClass:[NSPersistentStoreRequest class]], @"superclass is NSPersistentStoreRequest");
        expect([[request entityName] isEqual:@"Note"], @"entity name is kept");
        expect(request.entity == nil, @"no entity for the name initialiser");
        expect(request.includesSubentities, @"includesSubentities defaults to YES");
        expect(request.resultType == NSStatusOnlyResultType, @"result type defaults to status only");
        expect(request.requestType == NSBatchUpdateRequestType, @"request type is batch update");
        expect(request.predicate == nil && request.propertiesToUpdate == nil, @"no predicate or properties");

        NSMutableString *key = [NSMutableString stringWithString:@"title"];
        request.predicate = [NSPredicate predicateWithFormat:@"pinned == YES"];
        request.propertiesToUpdate = [NSDictionary dictionaryWithObject:@"x" forKey:key];
        request.resultType = NSUpdatedObjectsCountResultType;
        request.includesSubentities = NO;
        request.affectedStores = [NSArray arrayWithObject:@"store"];

        NSBatchUpdateRequest *copy = [[request copy] autorelease];
        expect(copy != request, @"copy is a new object");
        expect([copy isMemberOfClass:[NSBatchUpdateRequest class]], @"copy keeps the class");
        expect([[copy entityName] isEqual:@"Note"], @"copy keeps the entity name");
        expect([copy.predicate isEqual:request.predicate], @"copy keeps the predicate");
        expect([copy.propertiesToUpdate isEqual:request.propertiesToUpdate], @"copy keeps the properties");
        expect(copy.resultType == NSUpdatedObjectsCountResultType, @"copy keeps the result type");
        expect(!copy.includesSubentities, @"copy keeps includesSubentities");
        expect([copy.affectedStores isEqual:request.affectedStores], @"copy keeps affectedStores");
        NSLog(@"PASS: NSBatchUpdateRequest");
    }
    return 0;
}
