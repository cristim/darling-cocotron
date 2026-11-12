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

#import <AppKit/NSFilePromiseReceiver.h>
#import "NSStubForwarding-Private.h"

// Nothing creates a receiver yet: NSPasteboard cannot read promise objects, so
// the file lists are empty. Receiving fulfils nothing and never calls the
// reader, which is logged once.
@implementation NSFilePromiseReceiver

+ (NSArray<NSString *> *) readableDraggedTypes {
    return [NSArray array];
}

- (NSArray<NSString *> *) fileTypes {
    return [NSArray array];
}

- (NSArray<NSString *> *) fileNames {
    return [NSArray array];
}

- (void) receivePromisedFilesAtDestination: (NSURL *) destinationDir
                                   options: (NSDictionary<id, id> *) options
                            operationQueue: (NSOperationQueue *) operationQueue
                                    reader: (void (^)(NSURL *fileURL, NSError *errorOrNil)) reader {
    NSStubLogUnimplementedOnce([self class], _cmd);
}

@end
