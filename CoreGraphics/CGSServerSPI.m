/*
 This file is part of Darling.

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
#import <CoreGraphics/CGSServerSPI.h>
#import <CoreGraphics/CGWindowPrivate.h>
#include <math.h>

// GUESS: any fixed nonzero value gives one stable identifier per process.
static const CGSConnectionID mainConnectionID = 1;

CGSConnectionID CGSMainConnectionID(void)
{
    return mainConnectionID;
}

CGError CGSSetWindowAlpha(CGSConnectionID connection, CGSWindowID windowID,
                          float alpha)
{
    // GUESS: the identifier is the window number AppKit reports for the window.
    CGWindow *window = [CGWindow windowWithWindowNumber: windowID];
    // GUESS: an unknown window is an illegal argument.
    if (window == nil)
        return kCGErrorIllegalArgument;

    // GUESS: clamp to the NSWindow.alphaValue range (NaN becomes 0).
    [window setAlphaValue: fmin(fmax(alpha, 0.0), 1.0)];
    return kCGErrorSuccess;
}
