#import <Foundation/Foundation.h>
#import "../../NSPasteboardURIList.m"
#include <stdio.h>
static int checks, failures;
static void fileCheck(BOOL pass,const char *name) { checks++; if(!pass) failures++; printf("%s %s\n",pass?"PASS":"FAIL",name); }
static NSData *bytes(NSString *s) { return [s dataUsingEncoding:NSUTF8StringEncoding]; }
int main(void) {
 @autoreleasepool {
    NSArray *files=@[@"/Volumes/SystemRoot/tmp/a b#%日本語",@"/Volumes/SystemRoot/tmp/new\nline"];
    NSData *wire=NSPasteboardURIListFromFilenames(files);
    fileCheck([wire isEqual:bytes(@"file:///tmp/a%20b%23%25%E6%97%A5%E6%9C%AC%E8%AA%9E\r\nfile:///tmp/new%0Aline\r\n")],"exact UTF8 escaping and CRLF");
    fileCheck([NSPasteboardFilenamesFromURIList(wire) isEqual:files],"multi-file roundtrip");
    fileCheck([NSPasteboardFilenamesFromURIList(bytes(@"# comment\r\n\nFILE://LOCALHOST/tmp/a\r\nfile:/tmp/b\n")) isEqual:@[@"/Volumes/SystemRoot/tmp/a",@"/Volumes/SystemRoot/tmp/b"]],"comments localhost and case");
    for(NSString *bad in @[@"file://remote/tmp/a",@"file:relative",@"file:///a?query",@"file:///a#fragment",@"file:///a%",@"file:///a%GG",@"file:///a%00",@"file:///a%FF",@"file:///a/../b",@"file:///a/%2e%2e/b",@"file:////server/share",@"https://example.com/a",@"file:///raw space",@"file:///raw\rbreak",@"file:///a%2Fb",@"file:///a%2fb"]) {
        fileCheck(NSPasteboardFilenamesFromURIList(bytes(bad))==nil,[bad UTF8String]);
        fileCheck(NSPasteboardFilenamesFromURIList(bytes([@"file:///valid\n" stringByAppendingString:bad]))==nil,"invalid list entry rejects entire list");
    }
    fileCheck(NSPasteboardURIListFromFilenames(@[@"/tmp/guest-only"])==nil,"guest-only export refused");
    fileCheck(NSPasteboardURIListFromFilenames(@[@"/Volumes/SystemRoot/tmp/ok",@"/tmp/guest-only"])==nil,"mixed export all-or-nothing");
    fileCheck(NSPasteboardURIListFromFilenames(@[@"/Volumes/SystemRooted/tmp/no"])==nil,"host boundary exact");
    fileCheck(NSPasteboardURIListFromFilenames(@[@"/Volumes/SystemRoot/tmp/../no"])==nil,"export parent traversal refused");
    fileCheck(NSPasteboardURIListFromFilenames(@[@42])==nil,"non-string entry refused");
    fileCheck(NSPasteboardURIListFromFilenames(@[])==nil,"empty export refused");
    fileCheck(NSPasteboardFilenamesFromURIList(bytes(@"# only comment\n"))==nil,"empty URI selection refused");
    char nul[]="file:///tmp/a\0hidden";
    fileCheck(NSPasteboardFilenamesFromURIList([NSData dataWithBytes:nul length:sizeof(nul)-1])==nil,"embedded NUL refused");
    NSString *longPath=[@"/Volumes/SystemRoot/" stringByPaddingToLength:4096 withString:@"a" startingAtIndex:0];
    fileCheck(NSPasteboardURIListFromFilenames(@[longPath])==nil,"path bound");
    fileCheck(NSPasteboardFilenamesFromURIList(bytes([@"file:///" stringByPaddingToLength:16384 withString:@"a/" startingAtIndex:0]))==nil,"overlong component sequence refused");
    NSString *many=[@"" stringByPaddingToLength:4097 withString:@"\n" startingAtIndex:0];
    fileCheck(NSPasteboardFilenamesFromURIList(bytes(many))==nil,"excessive blank records refused before split");
    // The byte bound includes the /Volumes/SystemRoot prefix on import too, as the
    // X11 backend now shares this parser.
    NSString *nearLimit=[@"file:///" stringByPaddingToLength:7+4090 withString:@"a" startingAtIndex:0];
    fileCheck(NSPasteboardFilenamesFromURIList(bytes(nearLimit))==nil,"import path bound includes host root");
    fileCheck(NSPasteboardFilenamesFromURIList(bytes([nearLimit substringToIndex:7+4000]))!=nil,"long path below bound accepted");
    NSMutableArray *manyFiles=[NSMutableArray array];
    for(int i=0;i<4097;i++)[manyFiles addObject:@"/Volumes/SystemRoot/tmp/a"];
    fileCheck(NSPasteboardURIListFromFilenames(manyFiles)==nil,"excessive file records refused");
    // Single-URL views used by NSPasteboardTypeFileURL and NSPasteboardTypeURL.
    NSString *firstURL=@"file:///Volumes/SystemRoot/tmp/a%20b%23%25%E6%97%A5%E6%9C%AC%E8%AA%9E";
    fileCheck([NSPasteboardFileURLStringFromURIList(wire) isEqual:firstURL],"file URL is the first file, guest-visible and escaped");
    fileCheck([NSPasteboardURLStringFromURIList(wire) isEqual:firstURL],"URL of a file list is the first file URL");
    fileCheck(NSPasteboardFileURLStringFromURIList(bytes(@"https://example.com/a\r\n"))==nil,"file URL refuses non-file record");
    fileCheck(NSPasteboardFileURLStringFromURIList(bytes(@"file:///a\nhttps://example.com/\n"))==nil,"file URL of a mixed list is atomic");
    fileCheck([NSPasteboardURLStringFromURIList(bytes(@"# c\r\nhttps://example.com/a?b=c#d\r\nhttps://example.org/\r\n")) isEqual:@"https://example.com/a?b=c#d"],"URL is the first non-comment record");
    fileCheck(NSPasteboardURLStringFromURIList(bytes(@"file:///a%GG\n"))==nil,"URL never leaks a malformed file record");
    fileCheck(NSPasteboardURLStringFromURIList(bytes(@"https://exa mple.com\n"))==nil,"URL refuses embedded space");
    fileCheck([NSPasteboardURIListFromURLString(firstURL) isEqual:bytes(@"file:///tmp/a%20b%23%25%E6%97%A5%E6%9C%AC%E8%AA%9E\r\n")],"file URL exports host-relative URI");
    fileCheck([NSPasteboardURIListFromURLString(@"https://example.com/a?b=c")isEqual:bytes(@"https://example.com/a?b=c\r\n")],"plain URL exports one CRLF record");
    fileCheck(NSPasteboardURIListFromURLString(@"file:///tmp/guest-only")==nil,"file URL outside host root refused");
    fileCheck(NSPasteboardURIListFromURLString(@"https://example.com/\r\nfile:///x")==nil,"URL with CRLF refused");
    fileCheck(NSPasteboardURIListFromURLString(@"")==nil && NSPasteboardURIListFromURLString((NSString*)@42)==nil,"empty and non-string URL refused");
    fileCheck(NSPasteboardURIListFromURLString(@"#comment")==nil && NSPasteboardURIListFromURLString(@"example.com")==nil,"comment-looking and schemeless URL refused");
    fileCheck(NSPasteboardURIListFromURLString(@"https://exämple.com/")==nil,"non-ASCII URL refused");
    fileCheck(NSPasteboardURIListHasFileURI(bytes(@"https://a/\nFILE:///x%GG\n")) && !NSPasteboardURIListHasFileURI(bytes(@"https://a/\n")),"file record detection ignores validity");
    printf("RESULT checks=%d failures=%d\n",checks,failures);
 }
 return failures?1:0;
}
