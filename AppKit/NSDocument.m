/* Copyright (c) 2006-2007 Christopher J. W. Lloyd <cjwl@objc.net>

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE. */

#import "NSKeyValueBinding/NSObject+BindingSupport.h"
#import <AppKit/NSApplication.h>
#import <AppKit/NSDocument.h>
#import <AppKit/NSDocumentController.h>
#import <AppKit/NSFileWrapper.h>
#import <AppKit/NSMenuItem.h>
#import <AppKit/NSPageLayout.h>
#import <AppKit/NSPrintInfo.h>
#import <AppKit/NSPrintOperation.h>
#import <AppKit/NSRaise.h>
#import <AppKit/NSSavePanel.h>
#import <AppKit/NSWindowController.h>
#import <dispatch/dispatch.h>
#import <objc/runtime.h>

// Declared by NSDocument subclasses that autosave in place (macOS 10.7).
@interface NSObject (NSDocumentAutosavesInPlace)
+ (BOOL) autosavesInPlace;
@end

@implementation NSDocument

static int untitled_document_number = 0;

+ (NSArray *) readableTypes {
    NSLog(@"TEDIAG enter +readableTypes");
    NSArray *knownDocTypes =
            [[NSBundle mainBundle] infoDictionary][@"CFBundleDocumentTypes"];
    NSMutableArray *readableTypes = [NSMutableArray array];

    for (NSDictionary *typeDict in knownDocTypes) {
        NSString *typeRole = typeDict[@"CFBundleTypeRole"];
        Class documentClass =
                NSClassFromString((NSString *) typeDict[@"NSDocumentClass"]);
        if (documentClass == self && ([typeRole isEqualToString: @"Viewer"] ||
                                      [typeRole isEqualToString: @"Editor"])) {
            NSString *typeName = typeDict[@"CFBundleTypeName"];
            if (typeName)
                [readableTypes addObject: typeName];
        }
    }

    return [NSArray arrayWithArray: readableTypes];
}

+ (NSArray *) writableTypes {
    NSLog(@"TEDIAG enter +writableTypes");
    NSArray *knownDocTypes =
            [[NSBundle mainBundle] infoDictionary][@"CFBundleDocumentTypes"];
    NSMutableArray *writableTypes = [NSMutableArray array];

    for (NSDictionary *typeDict in knownDocTypes) {
        NSString *typeRole = typeDict[@"CFBundleTypeRole"];
        Class documentClass =
                NSClassFromString((NSString *) typeDict[@"NSDocumentClass"]);
        if (documentClass == self && [typeRole isEqualToString: @"Editor"]) {
            NSString *typeName = typeDict[@"CFBundleTypeName"];
            if (typeName)
                [writableTypes addObject: typeName];
        }
    }

    return [NSArray arrayWithArray: writableTypes];
}

+ (BOOL) isNativeType: (NSString *) type {
    NSLog(@"TEDIAG enter +isNativeType");
    BOOL result = NO;
    NSArray *knownDocTypes =
            [[NSBundle mainBundle] infoDictionary][@"CFBundleDocumentTypes"];

    for (NSDictionary *typeDict in knownDocTypes) {
        NSString *typeRole = typeDict[@"CFBundleTypeRole"];
        NSString *typeName = typeDict[@"CFBundleTypeName"];
        Class documentClass =
                NSClassFromString((NSString *) typeDict[@"NSDocumentClass"]);
        result |= documentClass == self &&
                  [typeRole isEqualToString: @"Editor"] &&
                  [typeName isEqualToString: type];
    }

    return result;
}

- (BOOL) _isSelectorOverridden: (SEL) selector {
    NSLog(@"TEDIAG enter -_isSelectorOverridden");
    IMP mine = [NSDocument instanceMethodForSelector: selector];
    IMP theirs = [self methodForSelector: selector];

    return mine != theirs;
}

- (instancetype) init {
    NSLog(@"TEDIAG enter -init");
    self = [super init];
    if (self) {
        _windowControllers = [NSMutableArray new];
        _untitledNumber = untitled_document_number++;
        _hasUndoManager = YES;
        _activeEditors = [NSMutableArray new];
    }
    return self;
}

- (instancetype) initWithType: (NSString *) type error: (NSError **) error {
    NSLog(@"TEDIAG enter -initWithType");
    [self init];
    [self setFileType: type];
    return self;
}

- (void) _updateFileModificationDate {
    NSLog(@"TEDIAG enter -_updateFileModificationDate");
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *path = [_fileURL path];
    if (path != nil) {
        NSDictionary *attributes = [fileManager fileAttributesAtPath: path
                                                        traverseLink: YES];
        [self setFileModificationDate: attributes[NSFileModificationDate]];
    }
}

- (instancetype) initWithContentsOfURL: (NSURL *) url
                                ofType: (NSString *) type
                                 error: (NSError **) error
{
    NSLog(@"TEDIAG enter -initWithContentsOfURL");
    if ([self _isSelectorOverridden: @selector(initWithContentsOfFile:
                                                               ofType:)]) {
        if ([self initWithContentsOfFile: [url path] ofType: type] == nil)
            return nil;
    } else {
        [self init];
        [self setFileURL: url];
        [self setFileType: type];
        if (![self readFromURL: url ofType: type error: error]) {
            [self dealloc];
            return nil;
        }
    }
    [self _updateFileModificationDate];
    return self;
}

- (instancetype) initForURL: (NSURL *) url
          withContentsOfURL: (NSURL *) contentsURL
                     ofType: (NSString *) type
                      error: (NSError **) error
{
    NSLog(@"TEDIAG enter -initForURL");
    [self init];
    [self setFileURL: url];
    [self setFileType: type];
    if (contentsURL != nil) {
        if (![self readFromURL: contentsURL ofType: type error: error]) {
            [self dealloc];
            return nil;
        }
    }
    [self _updateFileModificationDate];
    return self;
}

- (void) dealloc {
    NSLog(@"TEDIAG enter -dealloc");
    [[NSNotificationCenter defaultCenter] removeObserver: self];

    [_windowControllers release];
    [_fileURL release];
    [_fileType release];
    [_fileModificationDate release];
    [_lastComponentOfFileName release];
    [_autosavedContentsFileURL release];
    [_printInfo release];
    [_undoManager release];
    [_activeEditors release];

    [super dealloc];
}

- (NSURL *) autosavedContentsFileURL {
    NSLog(@"TEDIAG enter -autosavedContentsFileURL");
    return _autosavedContentsFileURL;
}

- (NSDate *) fileModificationDate {
    NSLog(@"TEDIAG enter -fileModificationDate");
    return _fileModificationDate;
}

- (NSURL *) fileURL {
    NSLog(@"TEDIAG enter -fileURL");
    return _fileURL;
}

- (NSPrintInfo *) printInfo {
    NSLog(@"TEDIAG enter -printInfo");
    return _printInfo ? _printInfo : [NSPrintInfo sharedPrintInfo];
}

- (NSString *) fileType {
    NSLog(@"TEDIAG enter -fileType");
    NSString *result = _fileType;

    if (result == nil) {
        // when `_fileType` is `nil`, it seems this method returns the first element of `[self writableTypesForSaveOperation: NSSaveOperation]`.
        // i initially thought that `_fileType` was merely initialized to this value in `init`, but it turns out that setting it to `nil` and then
        // querying it returns the default value again. checking for it here is simpler than initializing it in `init` + resetting it in `setFileType:`.
        // plus, it seems that certain programs (Xcode, of course) depend on this being checked here rather than in `init` (and without ever calling `setFileType:`).
        result = [self writableTypesForSaveOperation: NSSaveOperation].firstObject;
    }

    return [[result retain] autorelease];
}

- (BOOL) hasUndoManager {
    NSLog(@"TEDIAG enter -hasUndoManager");
    return _hasUndoManager;
}

- (NSUndoManager *) undoManager {
    NSLog(@"TEDIAG enter -undoManager");
    if (_undoManager == nil && _hasUndoManager == YES) {
        [self setUndoManager: [NSUndoManager new]];
        [_undoManager beginUndoGrouping];
    }

    return _undoManager;
}

- (void) setAutosavedContentsFileURL: (NSURL *) url {
    NSLog(@"TEDIAG enter -setAutosavedContentsFileURL");
    url = [url copy];
    [_autosavedContentsFileURL release];
    _autosavedContentsFileURL = url;
}

- (void) setFileModificationDate: (NSDate *) value {
    NSLog(@"TEDIAG enter -setFileModificationDate");
    value = [value copy];
    [_fileModificationDate release];
    _fileModificationDate = value;
}

- (void) setFileURL: (NSURL *) url {
    NSLog(@"TEDIAG enter -setFileURL");
    url = [url copy];
    [_fileURL release];
    _fileURL = url;
    [_windowControllers makeObjectsPerformSelector: @selector
                        (synchronizeWindowTitleWithDocumentName)];
}

- (void) setPrintInfo: (NSPrintInfo *) value {
    NSLog(@"TEDIAG enter -setPrintInfo");
    value = [value copy];
    [_printInfo release];
    _printInfo = value;
}

- (void) setFileType: (NSString *) type {
    NSLog(@"TEDIAG enter -setFileType");
    type = [type copy];
    [_fileType release];
    _fileType = type;
}

- (void) setHasUndoManager: (BOOL) flag {
    NSLog(@"TEDIAG enter -setHasUndoManager");
    _hasUndoManager = flag;
    if (flag == YES && _undoManager == nil)
        [self undoManager];
    else if (flag == NO && _undoManager != nil)
        [self setUndoManager: nil];
}

- (void) setUndoManager: (NSUndoManager *) undoManager {
    NSLog(@"TEDIAG enter -setUndoManager");
    if (_undoManager != nil) {
        [[NSNotificationCenter defaultCenter]
                removeObserver: self
                          name: NSUndoManagerDidUndoChangeNotification
                        object: _undoManager];
        [[NSNotificationCenter defaultCenter]
                removeObserver: self
                          name: NSUndoManagerDidRedoChangeNotification
                        object: _undoManager];
        [[NSNotificationCenter defaultCenter]
                removeObserver: self
                          name: NSUndoManagerWillCloseUndoGroupNotification
                        object: _undoManager];
        [_undoManager release];
    }

    _undoManager = [undoManager retain];

    if (undoManager) {
        // Only add observers if we have an undoManager we're concerned about
        [[NSNotificationCenter defaultCenter]
                addObserver: self
                   selector: @selector(_undoManagerDidUndoChange:)
                       name: NSUndoManagerDidUndoChangeNotification
                     object: _undoManager];
        [[NSNotificationCenter defaultCenter]
                addObserver: self
                   selector: @selector(_undoManagerDidRedoChange:)
                       name: NSUndoManagerDidRedoChangeNotification
                     object: _undoManager];
        [[NSNotificationCenter defaultCenter]
                addObserver: self
                   selector: @selector(_undoManagerDidCloseGroup:)
                       name: NSUndoManagerWillCloseUndoGroupNotification
                     object: _undoManager];
    }
}

- (NSUndoManager *) windowWillReturnUndoManager: (NSWindow *) window {
    NSLog(@"TEDIAG enter -windowWillReturnUndoManager");
    if (_hasUndoManager)
        return [self undoManager];

    return nil;
}

// There's no separate autosave state: unsaved edits are unautosaved.
- (BOOL) hasUnautosavedChanges {
    NSLog(@"TEDIAG enter -hasUnautosavedChanges");
    return [self isDocumentEdited];
}

- (NSString *) autosavingFileType {
    NSLog(@"TEDIAG enter -autosavingFileType");
    return [self fileType];
}

- (void) setLastComponentOfFileName: (NSString *) name {
    NSLog(@"TEDIAG enter -setLastComponentOfFileName");
    name = [name copy];
    [_lastComponentOfFileName release];
    _lastComponentOfFileName = name;
}

- (NSString *) windowNibName {
    NSLog(@"TEDIAG enter -windowNibName");
    return nil;
}

- (void) setWindow: (NSWindow *) window {
    NSLog(@"TEDIAG enter -setWindow");
    [[_windowControllers objectAtIndex: 0] setWindow: window];
}

- (void) windowControllerDidLoadNib: (NSWindowController *) controller {
    NSLog(@"TEDIAG enter -windowControllerDidLoadNib");
    // do nothing
}

- (void) windowControllerWillLoadNib: (NSWindowController *) controller {
    NSLog(@"TEDIAG enter -windowControllerWillLoadNib");
    // do nothing
}

- (void) showWindows {
    NSLog(@"TEDIAG enter -showWindows");
    [_windowControllers makeObjectsPerformSelector: @selector(showWindow:)
                                        withObject: self];
}

- (void) makeWindowControllers {
    NSLog(@"TEDIAG enter -makeWindowControllers");
    NSString *nibName = [self windowNibName];

    if (nibName != nil) {
        NSWindowController *controller = [[[NSWindowController alloc]
                initWithWindowNibName: nibName
                                owner: self] autorelease];

        [self addWindowController: controller];
    }
}

- (NSArray *) windowControllers {
    NSLog(@"TEDIAG enter -windowControllers");
    return _windowControllers;
}

- (void) addWindowController: (NSWindowController *) controller {
    NSLog(@"TEDIAG enter -addWindowController");
    [_windowControllers addObject: controller];
    if ([controller document] == nil)
        [controller setDocument: self];
}

- (void) removeWindowController: (NSWindowController *) controller {
    NSLog(@"TEDIAG enter -removeWindowController");
    [controller setDocument: nil];
    [_windowControllers removeObjectIdenticalTo: controller];
}

- (NSString *) displayName {
    NSLog(@"TEDIAG enter -displayName");
    if (_fileURL == nil) {
        NSString *untitledName = NSLocalizedStringFromTableInBundle(
                @"Untitled", nil, [NSBundle bundleForClass: [NSDocument class]],
                @"The name of a untitled document");
        if (_untitledNumber != 0)
            return [NSString
                    stringWithFormat: @"%@ %d", untitledName, _untitledNumber];
        else
            return untitledName;
    } else {
        return [[NSFileManager defaultManager]
                displayNameAtPath: [_fileURL path]];
    }
}

- (NSWindow *) windowForSheet {
    NSLog(@"TEDIAG enter -windowForSheet");
    if ([_windowControllers count] > 0) {
        NSWindow *check = [[_windowControllers objectAtIndex: 0] window];

        if (check != nil)
            return check;
    }

    return [NSApp mainWindow];
}

- (BOOL) isDocumentEdited {
    NSLog(@"TEDIAG enter -isDocumentEdited");
    return _changeCount != 0 || [_activeEditors count] > 0;
}

- (BOOL) isDraft {
    NSLog(@"TEDIAG enter -isDraft");
    return _draft;
}

- (void) setDraft: (BOOL) value {
    NSLog(@"TEDIAG enter -setDraft");
    _draft = value;
}

- (void) updateChangeCount: (NSDocumentChangeType) changeType {
    NSLog(@"TEDIAG enter -updateChangeCount");
    int count = [_windowControllers count];

    switch (changeType) {
    case NSChangeDone:
        _changeCount++;
        break;

    case NSChangeUndone:
        _changeCount--;
        break;

    case NSChangeCleared:
        _changeCount = 0;
        [self _updateFileModificationDate]; // Since file was just saved or
                                            // reverted
        break;

    case NSChangeReadOtherContents:
    case NSChangeAutosaved:
        NSUnimplementedMethod();
        break;

    case NSChangeRedone:
        _changeCount++; //Opposite of Undo - this may be wrong
        break;
    }

    BOOL edited = [self isDocumentEdited];
    while (--count >= 0)
        [[_windowControllers objectAtIndex: count] setDocumentEdited: edited];

    NSTimeInterval delay = [[NSDocumentController sharedDocumentController] autosavingDelay];
    // _changeCount, not -hasUnautosavedChanges: an active editor would reschedule after every save.
    if (delay > 0 && !_autosaveScheduled && _changeCount != 0) {
        _autosaveScheduled = YES;
        [self performSelector: @selector(_autosaveAfterDelay) withObject: nil afterDelay: delay];
    }
}

- (void) _autosaveAfterDelay {
    NSLog(@"TEDIAG enter -_autosaveAfterDelay");
    _autosaveScheduled = NO;
    [self autosaveWithImplicitCancellability: YES
                           completionHandler: ^(NSError *error) {
                               if (error)
                                   NSLog(@"Autosaving %@ failed: %@", [self displayName], error);
                           }];
}

- (BOOL) readFromData: (NSData *) data
               ofType: (NSString *) type
                error: (NSError **) error
{
    NSLog(@"TEDIAG enter -readFromData");
    if ([self _isSelectorOverridden: @selector(loadDataRepresentation:ofType:)])
        return [self loadDataRepresentation: data ofType: type];
    else {
        [NSException raise: NSInternalInconsistencyException
                    format: @"-[%@ %s]", [self class], sel_getName(_cmd)];
        return NO;
    }
}

- (BOOL) readFromFileWrapper: (NSFileWrapper *) fileWrapper
                      ofType: (NSString *) type
                       error: (NSError **) error
{
    NSLog(@"TEDIAG enter -readFromFileWrapper");
    if ([self _isSelectorOverridden: @selector(loadFileWrapperRepresentation:
                                                                      ofType:)])
        return [self loadFileWrapperRepresentation: fileWrapper ofType: type];
    else
        return [self readFromData: [fileWrapper regularFileContents]
                           ofType: type
                            error: error];
}

- (BOOL) readFromURL: (NSURL *) url
              ofType: (NSString *) type
               error: (NSError **) error
{
    NSLog(@"TEDIAG enter -readFromURL");
    if ([url isFileURL]) {
        if ([self _isSelectorOverridden: @selector(readFromFile:ofType:)]) {
            return [self readFromFile: [url path] ofType: type];
        } else {

            NSFileWrapper *fileWrapper = [[[NSFileWrapper alloc]
                    initWithPath: [url path]] autorelease];

            return [self readFromFileWrapper: fileWrapper
                                      ofType: type
                                       error: error];
        }
    }

    return NO;
}

- (BOOL) revertToContentsOfURL: (NSURL *) url
                        ofType: (NSString *) type
                         error: (NSError **) error
{
    NSLog(@"TEDIAG enter -revertToContentsOfURL");
    if (![self readFromURL: url ofType: type error: error])
        return NO;

    [self updateChangeCount: NSChangeCleared];
    return YES;
}

- (NSData *) dataOfType: (NSString *) type error: (NSError **) error {
    NSLog(@"TEDIAG enter -dataOfType");
    if ([self _isSelectorOverridden: @selector(dataRepresentationOfType:)])
        return [self dataRepresentationOfType: type];

    [NSException raise: NSInternalInconsistencyException
                format: @"-[%@ %s]", [self class], sel_getName(_cmd)];
    return nil;
}

- (NSFileWrapper *) fileWrapperOfType: (NSString *) type
                                error: (NSError **) error
{
    NSLog(@"TEDIAG enter -fileWrapperOfType");
    if ([self _isSelectorOverridden: @selector
                (fileWrapperRepresentationOfType:)])
        return [self fileWrapperRepresentationOfType: type];
    else {
        NSData *data = [self dataOfType: type error: error];

        if (data == nil)
            return nil;

        return [[[NSFileWrapper alloc] initRegularFileWithContents: data]
                autorelease];
    }
}

- (BOOL) writeToURL: (NSURL *) url
             ofType: (NSString *) type
              error: (NSError **) error
{
    NSLog(@"TEDIAG enter -writeToURL");
    if ([self _isSelectorOverridden: @selector(writeToFile:ofType:)]) {
        return [self writeToFile: [url path] ofType: type];
    } else {
        NSFileWrapper *wrapper = [self fileWrapperOfType: type error: error];

        if (wrapper == nil)
            return NO;

        if (![wrapper writeToFile: [url path]
                         atomically: YES
                    updateFilenames: YES])
            return NO;

        return YES;
    }
}

- (BOOL) writeToURL: (NSURL *) url
                     ofType: (NSString *) type
           forSaveOperation: (NSSaveOperationType) operation
        originalContentsURL: (NSURL *) contentsURL
                      error: (NSError **) error
{
    NSLog(@"TEDIAG enter -writeToURL");
    BOOL status = NO;
    if ([self _isSelectorOverridden: @selector
                (writeToFile:ofType:originalFile:saveOperation:)]) {
        status = [self writeToFile: [url path]
                            ofType: type
                      originalFile: [contentsURL path]
                     saveOperation: operation];
    } else {
        status = [self writeToURL: url ofType: type error: error];
    }
    if (status == YES && [self fileURL] == nil) {
        // It's a new file that's been successfully saved to a url...
        // so note it for the open recent menu
        [[NSDocumentController sharedDocumentController]
                noteNewRecentDocumentURL: url];
    }
    return status;
}

- (BOOL) writeSafelyToURL: (NSURL *) url
                   ofType: (NSString *) type
         forSaveOperation: (NSSaveOperationType) operation
                    error: (NSError **) error
{
    NSLog(@"TEDIAG enter -writeSafelyToURL");
    if (![self writeToURL: url
                             ofType: type
                   forSaveOperation: operation
                originalContentsURL: url
                              error: error])
        return NO;

    NSDictionary *attributes = [self fileAttributesToWriteToURL: url
                                                         ofType: type
                                               forSaveOperation: operation
                                            originalContentsURL: url
                                                          error: error];

    if ([attributes count])
        [[NSFileManager defaultManager] changeFileAttributes: attributes
                                                      atPath: [url path]];

    return YES;
}

- (NSDictionary *) fileAttributesToWriteToURL: (NSURL *) url
                                       ofType: (NSString *) type
                             forSaveOperation: (NSSaveOperationType) operation
                          originalContentsURL: (NSURL *) contentsURL
                                        error: (NSError **) error
{
    NSLog(@"TEDIAG enter -fileAttributesToWriteToURL");
    NSMutableDictionary *result = [NSMutableDictionary dictionary];

    return result;
}

- (BOOL) keepBackupFile {
    NSLog(@"TEDIAG enter -keepBackupFile");
    return NO;
}

- (void) autosaveDocumentWithDelegate: delegate
                  didAutosaveSelector: (SEL) selector
                          contextInfo: (void *) info
{
    NSLog(@"TEDIAG enter -autosaveDocumentWithDelegate");
    NSError *error;

    if (![self writeToURL: [self autosavedContentsFileURL]
                             ofType: [self autosavingFileType]
                   forSaveOperation: NSAutosaveOperation
                originalContentsURL: [self fileURL]
                              error: &error]) {
    }

    NSUnimplementedMethod();
}

- (NSError *) willPresentError: (NSError *) error {
    NSLog(@"TEDIAG enter -willPresentError");
    // do nothing
    return error;
}

- (BOOL) presentError: (NSError *) error {
    NSLog(@"TEDIAG enter -presentError");
    return [[NSDocumentController sharedDocumentController]
            presentError: [self willPresentError: error]];
}

- (void) presentError: (NSError *) error
            modalForWindow: (NSWindow *) window
                  delegate: delegate
        didPresentSelector: (SEL) selector
               contextInfo: (void *) info
{
    NSLog(@"TEDIAG enter -presentError");
    [[NSDocumentController sharedDocumentController]
                  presentError: [self willPresentError: error]
                modalForWindow: window
                      delegate: delegate
            didPresentSelector: selector
                   contextInfo: info];
}

- (NSArray *) writableTypesForSaveOperation: (NSSaveOperationType) operation {
    NSLog(@"TEDIAG enter -writableTypesForSaveOperation");
    NSArray *result = [[self class] writableTypes];

    if (operation == NSSaveToOperation) {
        NSMutableArray *filtered = [NSMutableArray array];
        int i, count = [result count];

        for (i = 0; i < count; i++) {
            NSString *check = [result objectAtIndex: i];

            if ([[self class] isNativeType: check])
                [filtered addObject: check];
        }
        result = filtered;
    }

    return result;
}

- (BOOL) shouldRunSavePanelWithAccessoryView {
    NSLog(@"TEDIAG enter -shouldRunSavePanelWithAccessoryView");
    return YES;
}

- (BOOL) prepareSavePanel: (NSSavePanel *) savePanel {
    NSLog(@"TEDIAG enter -prepareSavePanel");
    return YES;
}

- (BOOL) fileNameExtensionWasHiddenInLastRunSavePanel {
    NSLog(@"TEDIAG enter -fileNameExtensionWasHiddenInLastRunSavePanel");
    NSUnimplementedMethod();
    return 0;
}

- (NSString *) fileTypeFromLastRunSavePanel {
    NSLog(@"TEDIAG enter -fileTypeFromLastRunSavePanel");
    NSUnimplementedMethod();
    return nil;
}

- (void) runModalSavePanelForSaveOperation: (NSSaveOperationType) operation
                                  delegate: delegate
                           didSaveSelector: (SEL) selector
                               contextInfo: (void *) context
{
    NSLog(@"TEDIAG enter -runModalSavePanelForSaveOperation");
    NSString *path = [_fileURL path];
    NSString *extension = [path pathExtension];
    if ([extension length] == 0) {
        extension = [[[NSDocumentController sharedDocumentController]
                fileExtensionsFromType: [self fileType]] firstObject];
    }
    NSSavePanel *savePanel = [NSSavePanel savePanel];
    [savePanel setRequiredFileType: extension];
    // Suggest a name before prepareSavePanel:, which may replace it.
    if (_fileURL) {
        // Suggest saving alongside the original file
        [savePanel setDirectory: [path stringByDeletingLastPathComponent]];
        [savePanel setNameFieldStringValue: [path lastPathComponent]];
    } else {
        [savePanel setNameFieldStringValue: [self displayName]];
    }

#if 0
    // setAllowedFileTypes: is unimplemented - so don't call it.
    NSArray* writableTypes = [self writableTypesForSaveOperation: operation];
    [savePanel setAllowedFileTypes: writableTypes];
#endif

    if ([self prepareSavePanel: savePanel] == NO) {
        // subclass was unable to prepare the save panel successfully
        // so bail
        return;
    }

    NSInteger saveResult = [savePanel runModal];
    if (saveResult) {
        NSString *savePath = [savePanel filename];
        NSString *extension = [savePath pathExtension];
        NSString *fileType = [[NSDocumentController sharedDocumentController]
                typeFromFileExtension: extension];
        // Types named only by content type identifiers list no extensions to match; like macOS, which takes the
        // type from the panel rather than the extension, keep the document's type.
        if (fileType == nil)
            fileType = [self fileType];

        [[NSUserDefaults standardUserDefaults]
                setObject: [savePath stringByDeletingLastPathComponent]
                   forKey: @"NSNavLastRootDirectory"];

        // Try the various saving methods that can be implemented by the
        // document subclass
        if ([self _isSelectorOverridden: @selector
                    (saveToFile:
                            saveOperation:delegate:didSaveSelector:contextInfo
                                         :)]) {
            [self saveToFile: savePath
                      saveOperation: operation
                           delegate: delegate
                    didSaveSelector: selector
                        contextInfo: context];
        } else {
            [self saveToURL: [savePanel URL]
                              ofType: fileType
                    forSaveOperation: operation
                            delegate: delegate
                     didSaveSelector: selector
                         contextInfo: context];
        }
    } else {
        // User cancelled the save panel...
        if ([delegate respondsToSelector: selector]) {
            // Tell delegate that file couldn't be saved.
            void (*delegateMethod)(id, SEL, id, BOOL, void *);
            delegateMethod =
                    (void (*)(id, SEL, id, BOOL,
                              void *)) [delegate methodForSelector: selector];
            delegateMethod(delegate, selector, self, NO, context);
        }
    }
}

- (void) saveDocumentWithDelegate: delegate
                  didSaveSelector: (SEL) selector
                      contextInfo: (void *) info
{
    NSLog(@"TEDIAG enter -saveDocumentWithDelegate");
    // First make sure there are no uncommitted changes
    for (id editor in [[_activeEditors copy] autorelease]) {
        [editor commitEditing];
    }

    // Do we already have a file on disk for this document?
    if (_fileURL != nil) {

        // Check if file has been changed by another process
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSString *path = [_fileURL path];
        NSDictionary *attributes = [fileManager fileAttributesAtPath: path
                                                        traverseLink: YES];
        NSDate *dateModified =
                [attributes objectForKey: NSFileModificationDate];
        if (attributes != nil &&
            ![dateModified isEqualToDate: _fileModificationDate]) {
            int result = NSRunAlertPanel(
                    [self displayName],
                    NSLocalizedStringFromTableInBundle(
                            @"Another user or process has changed this "
                            @"document's file "
                            @"on disk.\n\nIf you save now, those changes will "
                            @"be lost. "
                            @"Save anyway?",
                            nil, [NSBundle bundleForClass: [NSDocument class]],
                            @""),
                    NSLocalizedStringFromTableInBundle(
                            @"Don't Save", nil,
                            [NSBundle bundleForClass: [NSDocument class]], @""),
                    NSLocalizedStringFromTableInBundle(
                            @"Save", nil,
                            [NSBundle bundleForClass: [NSDocument class]], @""),
                    nil);
            if (result == NSAlertDefaultReturn) {
                // The user canceled the save operation.
                if ([delegate respondsToSelector: selector]) {
                    void (*delegateMethod)(id, SEL, id, BOOL, void *);
                    delegateMethod = (void (*)(id, SEL, id, BOOL, void *))
                            [delegate methodForSelector: selector];
                    delegateMethod(delegate, selector, self, NO, info);
                }
                return;
            }
        }

        if ([self _isSelectorOverridden: @selector
                    (saveToFile:
                            saveOperation:delegate:didSaveSelector:contextInfo
                                         :)]) {
            [self saveToFile: [_fileURL path]
                      saveOperation: NSSaveOperation
                           delegate: delegate
                    didSaveSelector: selector
                        contextInfo: info];
        } else {
            [self saveToURL: _fileURL
                              ofType: [self fileType]
                    forSaveOperation: NSSaveOperation
                            delegate: delegate
                     didSaveSelector: selector
                         contextInfo: info];
        }
    } else {
        [self runModalSavePanelForSaveOperation: NSSaveOperation
                                       delegate: delegate
                                didSaveSelector: selector
                                    contextInfo: info];
    }
}

- (BOOL) saveToURL: (NSURL *) url
                  ofType: (NSString *) type
        forSaveOperation: (NSSaveOperationType) operation
                   error: (NSError **) error
{
    NSLog(@"TEDIAG enter -saveToURL");
    if (url == nil) {
        return NO;
    } else {
        BOOL success = [self writeSafelyToURL: url
                                       ofType: type
                             forSaveOperation: operation
                                        error: error];

        if (success) {
            if (operation != NSSaveToOperation) {
                [self setFileURL: url];
                [self setFileType: type];
                [self setFileModificationDate: [NSDate date]];
            }
            [self updateChangeCount: NSChangeCleared];
        }
        return success;
    }
}

- (void) saveToURL: (NSURL *) url
                  ofType: (NSString *) type
        forSaveOperation: (NSSaveOperationType) operation
                delegate: delegate
         didSaveSelector: (SEL) selector
             contextInfo: (void *) info
{
    NSLog(@"TEDIAG enter -saveToURL");
    // Like macOS, go through the completion handler variant, which subclasses override.
    [self saveToURL: url
                       ofType: type
             forSaveOperation: operation
            completionHandler: ^(NSError *error) {
                if (error != nil &&
                    !([[error domain] isEqualToString: NSCocoaErrorDomain] &&
                      [error code] == NSUserCancelledError)) {
                    [self presentError: error];
                }

                if ([delegate respondsToSelector: selector]) {
                    void (*delegateMethod)(id, SEL, id, BOOL, void *);
                    delegateMethod = (void (*)(id, SEL, id, BOOL, void *))
                            [delegate methodForSelector: selector];
                    delegateMethod(delegate, selector, self, error == nil, info);
                }
            }];
}

- (BOOL) preparePageLayout: (NSPageLayout *) pageLayout {
    NSLog(@"TEDIAG enter -preparePageLayout");
    // do nothing
    return YES;
}

- (BOOL) shouldChangePrintInfo: (NSPrintInfo *) printInfo {
    NSLog(@"TEDIAG enter -shouldChangePrintInfo");
    // do nothing
    return YES;
}

- (void) runModalPageLayoutWithPrintInfo: (NSPrintInfo *) printInfo
                                delegate: delegate
                          didRunSelector: (SEL) selector
                             contextInfo: (void *) info
{
    NSLog(@"TEDIAG enter -runModalPageLayoutWithPrintInfo");
    int button = [[NSPageLayout pageLayout] runModalWithPrintInfo: printInfo];
    if ([delegate respondsToSelector: selector]) {
        // Tell delegate if the print info was updated.
        void (*delegateMethod)(id, SEL, id, BOOL, void *);
        delegateMethod =
                (void (*)(id, SEL, id, BOOL,
                          void *)) [delegate methodForSelector: selector];
        delegateMethod(delegate, selector, self, button == NSOKButton, info);
    }
}

- (void) runModalPrintOperation: (NSPrintOperation *) printOperation
                       delegate: delegate
                 didRunSelector: (SEL) selector
                    contextInfo: (void *) info
{
    NSLog(@"TEDIAG enter -runModalPrintOperation");
    NSWindow *docWindow = [self windowForSheet];
    [printOperation runOperationModalForWindow: docWindow
                                      delegate: delegate
                                didRunSelector: selector
                                   contextInfo: info];
}

- (NSPrintOperation *) printOperationWithSettings: (NSDictionary *) settings
                                            error: (NSError **) error
{
    NSLog(@"TEDIAG enter -printOperationWithSettings");
    NSLog(@"Implement %s in your subclass %@ of NSDocument to enable printing",
          sel_getName(_cmd), [self class]);
    return nil;
}

- (void) printDocumentWithSettings: (NSDictionary *) settings
                    showPrintPanel: (BOOL) showPrintPanel
                          delegate: delegate
                  didPrintSelector: (SEL) selector
                       contextInfo: (void *) contextInfo
{
    NSLog(@"TEDIAG enter -printDocumentWithSettings");
    if ([self _isSelectorOverridden: @selector(printShowingPrintPanel:)]) {
        [self printShowingPrintPanel: showPrintPanel];
        if (delegate != nil && selector != NULL) {
            void (*cb)(id, SEL, NSDocument *, BOOL, void *) =
                    (void (*)(id, SEL, NSDocument *, BOOL, void *)) objc_msgSend;
            cb(delegate, selector, self, YES, contextInfo);
        }
    } else {
        NSError *error = nil;
        NSPrintOperation *operation = nil;
        @try {
            operation = [self printOperationWithSettings: settings
                                                   error: &error];
        } @catch (NSException *ex) {
            NSLog(@"[NSDocument printOperationWithSettings:error:] raised exception: %@", ex);
            if (delegate != nil && selector != NULL) {
                void (*cb)(id, SEL, NSDocument *, BOOL, void *) =
                        (void (*)(id, SEL, NSDocument *, BOOL, void *)) objc_msgSend;
                cb(delegate, selector, self, NO, contextInfo);
            }
            return;
        }

        if (operation == nil) {
            if (delegate != nil && selector != NULL) {
                void (*cb)(id, SEL, NSDocument *, BOOL, void *) =
                        (void (*)(id, SEL, NSDocument *, BOOL, void *)) objc_msgSend;
                cb(delegate, selector, self, NO, contextInfo);
            }
            return;
        }
        [operation setShowsPrintPanel: showPrintPanel];
        [self runModalPrintOperation: operation
                            delegate: delegate
                      didRunSelector: selector
                         contextInfo: contextInfo];
    }
}

- (void) close {
    NSLog(@"TEDIAG enter -close");
    if (_autosaveScheduled) {
        _autosaveScheduled = NO;
        [NSObject cancelPreviousPerformRequestsWithTarget: self selector: @selector(_autosaveAfterDelay) object: nil];
    }

    // Make sure the controllers don't call -close on self again.

    NSArray *controllers = _windowControllers;
    _windowControllers = [NSMutableArray new];

    for (NSWindowController *controller in controllers) {
        [controller setShouldCloseDocument: NO];
        [controller close];
    }

    [controllers release];

    [[NSDocumentController sharedDocumentController] removeDocument: self];
}

- (void) canCloseDocumentWithDelegate: delegate
                  shouldCloseSelector: (SEL) selector
                          contextInfo: (void *) info
{
    NSLog(@"TEDIAG enter -canCloseDocumentWithDelegate");
    BOOL OKToClose;
    if ([self isDocumentEdited]) {
        NSString *fileName = [self fileName];
        if (fileName == nil)
            fileName = [self displayName];
        int result = NSRunAlertPanel(
                [[[NSBundle mainBundle] infoDictionary]
                        objectForKey: @"CFBundleName"],
                NSLocalizedStringFromTableInBundle(
                        @"Save changes to %@?", nil,
                        [NSBundle bundleForClass: [NSDocument class]], @""),
                NSLocalizedStringFromTableInBundle(
                        @"Yes", nil,
                        [NSBundle bundleForClass: [NSDocument class]], @""),
                NSLocalizedStringFromTableInBundle(
                        @"No", nil,
                        [NSBundle bundleForClass: [NSDocument class]], @""),
                NSLocalizedStringFromTableInBundle(
                        @"Cancel", nil,
                        [NSBundle bundleForClass: [NSDocument class]], @""),
                fileName);
        if (result == NSAlertDefaultReturn) {
            [self saveDocumentWithDelegate: delegate
                           didSaveSelector: selector
                               contextInfo: info];
            return;
        } else if (result == NSAlertAlternateReturn) {
            // Don't save
            OKToClose = YES;
        } else {
            // Canceled
            OKToClose = NO;
        }
    } else {
        // No unsaved changes
        OKToClose = YES;
    }

    if ([delegate respondsToSelector: selector]) {
        void (*delegateMethod)(id, SEL, id, BOOL, void *);
        delegateMethod =
                (void (*)(id, SEL, id, BOOL,
                          void *)) [delegate methodForSelector: selector];
        delegateMethod(delegate, selector, self, OKToClose, info);
    }
}

- (void) shouldCloseWindowController: (NSWindowController *) controller
                            delegate: delegate
                 shouldCloseSelector: (SEL) selector
                         contextInfo: (void *) info
{
    NSLog(@"TEDIAG enter -shouldCloseWindowController");
    if ([controller shouldCloseDocument] || [_windowControllers count] <= 1) {
        [self canCloseDocumentWithDelegate: delegate
                       shouldCloseSelector: selector
                               contextInfo: info];
    } else if ([delegate respondsToSelector: selector]) {
        void (*delegateMethod)(id, SEL, id, BOOL, void *);
        delegateMethod =
                (void (*)(id, SEL, id, BOOL,
                          void *)) [delegate methodForSelector: selector];
        delegateMethod(delegate, selector, self, YES, info);
    }
}

- (void) revertDocumentToSaved: sender {
    NSLog(@"TEDIAG enter -revertDocumentToSaved");
    int result = NSRunAlertPanel(
            nil,
            NSLocalizedStringFromTableInBundle(
                    @"%@ has been edited. Are you sure you want to undo "
                    @"changes?",
                    nil, [NSBundle bundleForClass: [NSDocument class]], @""),
            NSLocalizedStringFromTableInBundle(
                    @"Revert", nil,
                    [NSBundle bundleForClass: [NSDocument class]], @""),
            NSLocalizedStringFromTableInBundle(
                    @"Cancel", nil,
                    [NSBundle bundleForClass: [NSDocument class]], @""),
            nil, [self displayName]);

    if (result == NSAlertDefaultReturn) {
        for (id editor in [[_activeEditors copy] autorelease])
            [editor discardEditing];
        [self revertToSavedFromFile: [self fileName] ofType: [self fileType]];
    }
}

- (void) saveDocument: sender {
    NSLog(@"TEDIAG enter -saveDocument");
    [self saveDocumentWithDelegate: nil
                   didSaveSelector: NULL
                       contextInfo: NULL];
}

- (void) saveDocumentAs: sender {
    NSLog(@"TEDIAG enter -saveDocumentAs");
    [self runModalSavePanelForSaveOperation: NSSaveAsOperation
                                   delegate: nil
                            didSaveSelector: NULL
                                contextInfo: NULL];
}

- (void) saveDocumentTo: sender {
    NSLog(@"TEDIAG enter -saveDocumentTo");
    [self runModalSavePanelForSaveOperation: NSSaveToOperation
                                   delegate: nil
                            didSaveSelector: NULL
                                contextInfo: NULL];
}

- (void) printDocument: sender {
    NSLog(@"TEDIAG enter -printDocument");
    [self printDocumentWithSettings: nil
                     showPrintPanel: YES
                           delegate: nil
                   didPrintSelector: NULL
                        contextInfo: NULL];
}

- (void) runPageLayout: sender {
    NSLog(@"TEDIAG enter -runPageLayout");
    [[NSPageLayout pageLayout] runModal];
}

- (BOOL) validateUserInterfaceItem: (id<NSValidatedUserInterfaceItem>) item {
    NSLog(@"TEDIAG enter -validateUserInterfaceItem");
    if (sel_isEqual([item action], @selector(revertDocumentToSaved:)))
        return (_fileURL != nil) ? YES : NO;
    if (sel_isEqual([item action], @selector(saveDocument:)))
        return YES;
    if ([self respondsToSelector: [item action]])
        return YES;

    return NO;
}

- (void) objectDidBeginEditing: editor {
    NSLog(@"TEDIAG enter -objectDidBeginEditing");
    [_activeEditors addObject: editor];

    BOOL edited = [self isDocumentEdited];
    for (NSWindowController *wc in _windowControllers)
        [wc setDocumentEdited: edited];
}

- (void) objectDidEndEditing: editor {
    NSLog(@"TEDIAG enter -objectDidEndEditing");
    [_activeEditors removeObject: editor];

    BOOL edited = [self isDocumentEdited];
    for (NSWindowController *wc in _windowControllers)
        [wc setDocumentEdited: edited];
}

- (BOOL) validateMenuItem: (NSMenuItem *) item {
    NSLog(@"TEDIAG enter -validateMenuItem");
    if (sel_isEqual([item action], @selector(revertDocumentToSaved:)))
        return (_fileURL != nil) ? YES : NO;
    if (sel_isEqual([item action], @selector(saveDocument:)))
        return YES;
    if ([self respondsToSelector: [item action]])
        return YES;

    return NO;
}

- (BOOL) canCloseDocument {
    NSLog(@"TEDIAG enter -canCloseDocument");
    return YES;
}

- (NSData *) dataRepresentationOfType: (NSString *) type {
    NSLog(@"TEDIAG enter -dataRepresentationOfType");
    [NSException raise: NSInternalInconsistencyException
                format: @"-[%@ %s]", [self class], sel_getName(_cmd)];
    return nil;
}

- (NSDictionary *) fileAttributesToWriteToFile: (NSString *) path
                                        ofType: (NSString *) type
                                 saveOperation: (NSSaveOperationType) operation
{
    NSLog(@"TEDIAG enter -fileAttributesToWriteToFile");
    return [NSDictionary dictionary];
}

- (NSString *) fileName {
    NSLog(@"TEDIAG enter -fileName");
    return [_fileURL path];
}

- (NSString *) fileNameFromRunningSavePanelForSaveOperation:
        (NSSaveOperationType) operation
{
    NSLog(@"TEDIAG enter -fileNameFromRunningSavePanelForSaveOperation");
    NSUnimplementedMethod();
    return nil;
}

- (NSFileWrapper *) fileWrapperRepresentationOfType: (NSString *) type {
    NSLog(@"TEDIAG enter -fileWrapperRepresentationOfType");
    NSData *data = [self dataRepresentationOfType: type];

    if (data == nil)
        return nil;

    return [[[NSFileWrapper alloc] initRegularFileWithContents: data]
            autorelease];
}

- initWithContentsOfFile: (NSString *) path ofType: (NSString *) type {
    NSLog(@"TEDIAG enter -initWithContentsOfFile");
    NSURL *url = [NSURL fileURLWithPath: path];
    NSError *error;

    [self init];

    [self setFileName: path];
    [self setFileType: type];

    error = nil;
    if (![self readFromURL: url ofType: type error: &error]) {
        NSRunAlertPanel(
                nil,
                NSLocalizedStringFromTableInBundle(
                        @"Can't open file '%@'. Error = %@", nil,
                        [NSBundle bundleForClass: [NSDocument class]], @""),
                NSLocalizedStringFromTableInBundle(
                        @"OK", nil,
                        [NSBundle bundleForClass: [NSDocument class]], @""),
                nil, nil, path, error);
        [self dealloc];
        return nil;
    }
    [self _updateFileModificationDate];

    return self;
}

- (id) initWithContentsOfURL: (NSURL *) url ofType: (NSString *) type {
    NSLog(@"TEDIAG enter -initWithContentsOfURL");
    NSError *error;
    [self init];

    error = nil;
    [self setFileURL: url];
    [self setFileType: type];
    if (![self readFromURL: url ofType: type error: &error]) {
        NSRunAlertPanel(
                nil,
                NSLocalizedStringFromTableInBundle(
                        @"Can't open file '%@'. Error = %@", nil,
                        [NSBundle bundleForClass: [NSDocument class]], @""),
                NSLocalizedStringFromTableInBundle(
                        @"OK", nil,
                        [NSBundle bundleForClass: [NSDocument class]], @""),
                nil, nil, url, error);
        [self dealloc];
        return nil;
    }
    [self _updateFileModificationDate];

    return self;
}


- (BOOL) loadDataRepresentation: (NSData *) data ofType: (NSString *) type {
    NSLog(@"TEDIAG enter -loadDataRepresentation");
    [NSException raise: NSInternalInconsistencyException
                format: @"-[%@ %s]", [self class], sel_getName(_cmd)];
    return NO;
}

- (BOOL) loadFileWrapperRepresentation: (NSFileWrapper *) fileWrapper
                                ofType: (NSString *) type
{
    NSLog(@"TEDIAG enter -loadFileWrapperRepresentation");

    if ([fileWrapper isRegularFile])
        return [self loadDataRepresentation: [fileWrapper regularFileContents]
                                     ofType: type];

    return NO;
}

- (void) printShowingPrintPanel: (BOOL) flag {
    NSLog(@"TEDIAG enter -printShowingPrintPanel");
    // do nothing
}

- (BOOL) readFromFile: (NSString *) path ofType: (NSString *) type {
    NSLog(@"TEDIAG enter -readFromFile");
    NSData *data = [[NSData alloc] initWithContentsOfFile: path];

    if (data == nil)
        return NO;

    if (![self loadDataRepresentation: data ofType: type]) {
        [data release];
        return NO;
    }

    [data release];
    return YES;
}

- (BOOL) readFromURL: (NSURL *) url ofType: (NSString *) type {
    NSLog(@"TEDIAG enter -readFromURL");
    return [self readFromFile: [url path] ofType: type];
}

- (BOOL) revertToSavedFromFile: (NSString *) path ofType: (NSString *) type {
    NSLog(@"TEDIAG enter -revertToSavedFromFile");
    if ([self readFromFile: path ofType: type]) {
        [self updateChangeCount: NSChangeCleared];
        return YES;
    }

    return NO;
}

- (BOOL) revertToSavedFromURL: (NSURL *) url ofType: (NSString *) type {
    NSLog(@"TEDIAG enter -revertToSavedFromURL");
    if ([self readFromURL: url ofType: type]) {
        [self updateChangeCount: NSChangeCleared];
        return YES;
    }

    return NO;
}

- (int) runModalSavePanel: (NSSavePanel *) savePanel
        withAccessoryView: (NSView *) accessoryView
{
    NSLog(@"TEDIAG enter -runModalSavePanel");
    NSUnimplementedMethod();
    return 0;
}

- (int) runModalPageLayoutWithPrintInfo: (NSPrintInfo *) printInfo {
    NSLog(@"TEDIAG enter -runModalPageLayoutWithPrintInfo");
    return [[NSPageLayout pageLayout] runModalWithPrintInfo: printInfo];
}

- (void) setFileName: (NSString *) path {
    NSLog(@"TEDIAG enter -setFileName");
    if (path != nil)
        [self setFileURL: [NSURL fileURLWithPath: path]];
    else
        [self setFileURL: nil];
}

- (void) saveToFile: (NSString *) path
          saveOperation: (NSSaveOperationType) operation
               delegate: delegate
        didSaveSelector: (SEL) selector
            contextInfo: (void *) context
{
    NSLog(@"TEDIAG enter -saveToFile");
    if (path != nil) {
        BOOL success = [self writeWithBackupToFile: path
                                            ofType: _fileType
                                     saveOperation: operation];

        if (success) {
            if (operation != NSSaveToOperation)
                [self setFileName: path];
            [self updateChangeCount: NSChangeCleared];
        }

        if ([delegate respondsToSelector: selector]) {
            void (*delegateMethod)(id, SEL, id, BOOL, void *);
            delegateMethod =
                    (void (*)(id, SEL, id, BOOL,
                              void *)) [delegate methodForSelector: selector];
            delegateMethod(delegate, selector, self, success, context);
        }
    }
}

- (BOOL) shouldCloseWindowController: (NSWindowController *) controller {
    NSLog(@"TEDIAG enter -shouldCloseWindowController");
    if (![controller shouldCloseDocument])
        return NO;

    [self canCloseDocumentWithDelegate: nil
                   shouldCloseSelector: NULL
                           contextInfo: NULL];
    return YES;
}

- (BOOL) writeToFile: (NSString *) path ofType: (NSString *) type {
    NSLog(@"TEDIAG enter -writeToFile");
    NSData *data;

    if ([self _isSelectorOverridden: @selector(dataRepresentationOfType:)])
        data = [self dataRepresentationOfType: type];
    else
        data = [self dataOfType: type error: NULL];

    return [data writeToFile: path atomically: YES];
}

- (BOOL) writeToFile: (NSString *) path
               ofType: (NSString *) type
         originalFile: (NSString *) original
        saveOperation: (NSSaveOperationType) operation
{
    NSLog(@"TEDIAG enter -writeToFile");
    NSUnimplementedMethod();
    return 0;
}

- (BOOL) writeToURL: (NSURL *) url ofType: (NSString *) type {
    NSLog(@"TEDIAG enter -writeToURL");
    NSUnimplementedMethod();
    return 0;
}

- (BOOL) writeWithBackupToFile: (NSString *) path
                        ofType: (NSString *) type
                 saveOperation: (NSSaveOperationType) operation
{
    NSLog(@"TEDIAG enter -writeWithBackupToFile");
    // move original to backup

    if (![self writeToFile: path ofType: type])
        return NO;

    if (![self keepBackupFile]) {
        // delete backup
    }
    return YES;
}

- (void) _setUntitledNumber: (int) number {
    NSLog(@"TEDIAG enter -_setUntitledNumber");
    _untitledNumber = number;
}

- (void) _undoManagerDidUndoChange: (NSNotification *) note {
    NSLog(@"TEDIAG enter -_undoManagerDidUndoChange");
    [self updateChangeCount: NSChangeUndone];
}

- (void) _undoManagerDidRedoChange: (NSNotification *) note {
    NSLog(@"TEDIAG enter -_undoManagerDidRedoChange");
    [self updateChangeCount: NSChangeDone];
}

- (void) _undoManagerDidCloseGroup: (NSNotification *) note {
    NSLog(@"TEDIAG enter -_undoManagerDidCloseGroup");
    // FIXME: the following would mark just opened and otherwise pristine
    // documents as changed
    //  [self updateChangeCount:NSChangeDone];
}

- (BOOL) windowShouldClose: sender {
    NSLog(@"TEDIAG enter -windowShouldClose");
    if ([[NSUserDefaults standardUserDefaults] boolForKey: @"useSheets"]) {
        NSBeginAlertSheet(
                nil,
                NSLocalizedStringFromTableInBundle(
                        @"Yes", nil,
                        [NSBundle bundleForClass: [NSDocument class]], @""),
                NSLocalizedStringFromTableInBundle(
                        @"No", nil,
                        [NSBundle bundleForClass: [NSDocument class]], @""),
                NSLocalizedStringFromTableInBundle(
                        @"Cancel", nil,
                        [NSBundle bundleForClass: [NSDocument class]], @""),
                sender, self,
                @selector(didEndShouldCloseSheet:returnCode:contextInfo:), NULL,
                sender,
                NSLocalizedStringFromTableInBundle(
                        @"Save changes to %@?", nil,
                        [NSBundle bundleForClass: [NSDocument class]], @""),
                [self displayName]);

        return NO;
    } else {
        if (![self isDocumentEdited])
            return YES;
        else {
            int result = NSRunAlertPanel(
                    nil,
                    NSLocalizedStringFromTableInBundle(
                            @"Save changes to %@?", nil,
                            [NSBundle bundleForClass: [NSDocument class]], @""),
                    NSLocalizedStringFromTableInBundle(
                            @"Yes", nil,
                            [NSBundle bundleForClass: [NSDocument class]], @""),
                    NSLocalizedStringFromTableInBundle(
                            @"No", nil,
                            [NSBundle bundleForClass: [NSDocument class]], @""),
                    NSLocalizedStringFromTableInBundle(
                            @"Cancel", nil,
                            [NSBundle bundleForClass: [NSDocument class]], @""),
                    [self displayName]);

            switch (result) {
            case NSAlertDefaultReturn:
                [self saveDocument: nil];
                return YES;

            case NSAlertAlternateReturn:
                // Let's prep the document to close cleanly.
                for (id editor in [[_activeEditors copy] autorelease]) {
                    [editor discardEditing];
                }
                [self updateChangeCount: NSChangeCleared];
                return YES;

            case NSAlertOtherReturn:
            default:
                return NO;
            }
        }
    }
}

- (void) didEndShouldCloseSheet: (NSWindow *) sheet
                     returnCode: (int) returnCode
                    contextInfo: (void *) contextInfo
{
    NSLog(@"TEDIAG enter -didEndShouldCloseSheet");
    NSWindow *window = (NSWindow *) contextInfo;

    switch (returnCode) {
    case NSAlertDefaultReturn:
        [self saveDocument: nil];
        [window close];
        break;

    case NSAlertAlternateReturn:
        [window close];
        break;

    case NSAlertOtherReturn:
    default:
        break;
    }
}

#if 0
-(void)windowWillClose:(NSNotification *)note {
    NSLog(@"TEDIAG enter -windowWillClose");
   NSWindow *window=[note object];
   int       count=[_windowControllers count];

   while(--count>=0){
    NSWindowController *controller=[_windowControllers objectAtIndex:count];

    if([controller isWindowLoaded] && window==[controller window]){
     BOOL closeMe = [controller shouldCloseDocument]; 
     [_windowControllers removeObjectAtIndex:count]; 
     if (closeMe) 
      [self close]; 
     return; 
    }
   }
}
#endif

- (void) textDidChange: (NSNotification *) aNotification {
    NSLog(@"TEDIAG enter -textDidChange");
    [self updateChangeCount: NSChangeDone];
}

- (void) performSynchronousFileAccessUsingBlock: (void (^)(void)) block {
    NSLog(@"TEDIAG enter -performSynchronousFileAccessUsingBlock");
    // FIXME: this is just a stub for now that performs no synchronization
    block();
}

- (void) saveToURL: (NSURL *) url
            ofType: (NSString *) typeName
  forSaveOperation: (NSSaveOperationType) saveOperation
 completionHandler: (void (^)(NSError *errorOrNil)) completionHandler
 {
    NSLog(@"TEDIAG enter -saveToURL");
    // Saves synchronously, then calls the handler.
    NSError *error = nil;
    BOOL saved = [self saveToURL: url
                          ofType: typeName
                forSaveOperation: saveOperation
                           error: &error];
    if (!saved && error == nil)
        error = [NSError errorWithDomain: NSCocoaErrorDomain code: NSFileWriteUnknownError userInfo: nil];
    if (completionHandler)
        completionHandler(saved ? nil : error);
}

- (void) autosaveWithImplicitCancellability: (BOOL) autosavingIsImplicitlyCancellable
                          completionHandler: (void (^)(NSError *errorOrNil)) completionHandler
{
    NSLog(@"TEDIAG enter -autosaveWithImplicitCancellability");
    // Documents that autosave in place are saved to their file; otherwise, and
    // with nothing to save, there is no autosave location and nothing is written.
    if ([self hasUnautosavedChanges] && [self fileURL] != nil &&
        [[self class] respondsToSelector: @selector(autosavesInPlace)] &&
        [[self class] autosavesInPlace]) {
        [self saveToURL: [self fileURL]
                          ofType: [self autosavingFileType]
                forSaveOperation: NSAutosaveInPlaceOperation
               completionHandler: completionHandler];
        return;
    }
    if (completionHandler)
        completionHandler(nil);
}

- (void) continueActivityUsingBlock: (void (^)(void)) block {
    NSLog(@"TEDIAG enter -continueActivityUsingBlock");
    if (block)
        block();
}

- (void) unblockUserInteraction {
    NSLog(@"TEDIAG enter -unblockUserInteraction");
    // Saving is synchronous here: no asynchronous writer is holding the main
    // thread while a subclass creates its document snapshot.
}

- (void) continueAsynchronousWorkOnMainThreadUsingBlock: (void (^)(void)) block {
    NSLog(@"TEDIAG enter -continueAsynchronousWorkOnMainThreadUsingBlock");
    if (block)
        dispatch_async(dispatch_get_main_queue(), block);
}

- (void) performActivityWithSynchronousWaiting: (BOOL) waitSynchronously
                                    usingBlock: (void (^)(void (^activityCompletionHandler)(void))) block
{
    NSLog(@"TEDIAG enter -performActivityWithSynchronousWaiting");
    if (block)
        block(^{
        });
}

- (void) performAsynchronousFileAccessUsingBlock: (void (^)(void (^fileAccessCompletionHandler)(void))) block {
    NSLog(@"TEDIAG enter -performAsynchronousFileAccessUsingBlock");
    if (block)
        block(^{
        });
}

- (void) browseDocumentVersions: (id) sender {
    NSLog(@"TEDIAG enter -browseDocumentVersions");
}

- (void) invalidateRestorableState {
    NSLog(@"TEDIAG enter -invalidateRestorableState");
}

+ (NSArray *) restorableStateKeyPaths {
    NSLog(@"TEDIAG enter +restorableStateKeyPaths");
    return [NSArray array];
}

- (void) encodeRestorableStateWithCoder: (NSCoder *) coder {
    NSLog(@"TEDIAG enter -encodeRestorableStateWithCoder");
}

- (void) encodeRestorableStateWithCoder: (NSCoder *) coder backgroundQueue: (NSOperationQueue *) queue {
    NSLog(@"TEDIAG enter -encodeRestorableStateWithCoder");
    [self encodeRestorableStateWithCoder: coder];
}

- (void) restoreStateWithCoder: (NSCoder *) coder {
    NSLog(@"TEDIAG enter -restoreStateWithCoder");
}

- (void) restoreDocumentWindowWithIdentifier: (NSString *) identifier
                                       state: (NSCoder *) state
                           completionHandler: (void (^)(NSWindow *window, NSError *error)) completionHandler
{
    NSLog(@"TEDIAG enter -restoreDocumentWindowWithIdentifier");
    if ([[self windowControllers] count] == 0) {
        [self makeWindowControllers];
    }
    for (NSWindowController *controller in [self windowControllers]) {
        NSWindow *window = [controller window];
        if ([[window identifier] isEqualToString: identifier]) {
            completionHandler(window, nil);
            return;
        }
    }
    completionHandler(nil, [NSError errorWithDomain: NSCocoaErrorDomain code: NSFeatureUnsupportedError userInfo: nil]);
}

@end

@implementation NSDocument (NSDocumentViewingAndSaveType)

- (BOOL) isInViewingMode {
    NSLog(@"TEDIAG enter -isInViewingMode");
    return NO;
}

- (void) changeSaveType: (id) sender {
    NSLog(@"TEDIAG enter -changeSaveType");
}

@end
