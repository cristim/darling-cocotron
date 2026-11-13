/*
 This file is part of Darling.

 Copyright (C) 2026 Darling developers

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

// UIFoundation sits below AppKit and must not import anything from it at link
// time (run check-boundary.sh on the linked images). The few AppKit classes and
// functions the text classes still reach are looked up here at run time and
// fail loudly when AppKit is not loaded.

#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <CoreGraphics/CGContext.h>

@class NSColor, NSFont;

// Hidden, like everything below: AppKit re-exports UIFoundation and must not hand its clients UIFoundation's
// private helpers.
#define UIF_PRIVATE __attribute__((visibility("hidden")))

UIF_PRIVATE Class UIFRequireAppKitClass(const char *name);
UIF_PRIVATE void *UIFRequireAppKitSymbol(const char *name);

// Class object of an AppKit class, looked up once per use site.
#define UIFAppKitClass(name) \
    ({ static Class uifClass_; \
       if (uifClass_ == Nil) \
           uifClass_ = UIFRequireAppKitClass(#name); \
       uifClass_; })

// Address of an AppKit C function or global, looked up once per use site.
#define UIFAppKitSymbol(name) \
    ({ static void *uifSymbol_; \
       if (uifSymbol_ == NULL) \
           uifSymbol_ = UIFRequireAppKitSymbol(#name); \
       uifSymbol_; })

// NSCurrentGraphicsPort() and NSRectFill() of AppKit.
#define UIFCurrentGraphicsPort() \
    (((CGContextRef (*)(void)) UIFAppKitSymbol(NSCurrentGraphicsPort))())
#define UIFRectFill(rect) \
    (((void (*)(NSRect)) UIFAppKitSymbol(NSRectFill))(rect))

// The font and foreground colour of an attribute dictionary, with the defaults
// AppKit's attribute helpers use (Arial 12, black).
UIF_PRIVATE NSFont *UIFFontAttributeInDictionary(NSDictionary *attributes);
UIF_PRIVATE NSColor *UIFForegroundColorAttributeInDictionary(NSDictionary *attributes);

// NSViewFrameDidChangeNotification of AppKit.
#define UIFViewFrameDidChangeNotification \
    (*(NSString *const *) UIFAppKitSymbol(NSViewFrameDidChangeNotification))
