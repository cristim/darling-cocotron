/* Permission is hereby granted, free of charge, to any person obtaining a copy of
 this software and associated documentation files (the "Software"), to deal in
 the Software without restriction, including without limitation the rights to
 use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
 of the Software, and to permit persons to whom the Software is furnished to do
 so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in all
 copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 SOFTWARE. */

#pragma once
#import <Foundation/Foundation.h>

// RFC 2483 text/uri-list codec shared by the X11 and Wayland backends. Pure and
// all-or-nothing: neither function touches the filesystem, and an invalid entry
// fails the whole list. Host paths are exposed to the guest under
// /Volumes/SystemRoot.
//
// Returns the guest-visible filenames, or nil if the list is empty or any record
// is not a well-formed local file URI.
NSArray *NSPasteboardFilenamesFromURIList(NSData *data);
// Returns CRLF-terminated file URIs, or nil unless every name is under
// /Volumes/SystemRoot and a valid host path.
NSData *NSPasteboardURIListFromFilenames(NSArray *filenames);
