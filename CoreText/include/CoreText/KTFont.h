/* Copyright (c) 2006-2008 Christopher J. W. Lloyd

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
#import <CoreGraphics/CoreGraphics.h>
#import <CoreText/CTFont.h>
#import <CoreText/CoreTextExport.h>
#import <Foundation/NSString.h>

enum { CGNullGlyph = 0x0 };

// A CTFontRef is any object that answers -cgFont and -pointSize; the CTFont
// functions derive everything else from those two. KTFont is CoreText's own
// such class, used when no other class is registered.
@interface KTFont : NSObject {
    CGFontRef _font;
    CGFloat _size;
}

- initWithFont: (CGFontRef) font size: (CGFloat) size;

- (CFStringRef) copyName;
- (CGFontRef) cgFont;
- (CGFloat) pointSize;

@end

// Makes CoreText create every font as an instance of fontClass, which must
// answer -initWithFont:size:, -cgFont and -pointSize. AppKit registers NSFont
// from +load. Raises if CoreText has already created a font, or if another
// class is already registered: fonts must never be of two classes.
CORETEXT_EXPORT void _CTFontSetConcreteClass(Class fontClass);
