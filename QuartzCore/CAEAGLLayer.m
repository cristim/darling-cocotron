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

#import <QuartzCore/CAEAGLLayer.h>

// OpenGL ES drawing is not implemented; the layer stores its two documented
// properties. presentsWithTransaction defaults to NO, a GUESS (rung 6): the
// page describes the default as presenting asynchronously to transactions.
@implementation CAEAGLLayer

@synthesize drawableProperties = _drawableProperties;
@synthesize presentsWithTransaction = _presentsWithTransaction;

- (void) dealloc {
    [_drawableProperties release];
    [super dealloc];
}

@end
