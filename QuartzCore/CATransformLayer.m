/*
 * This file is part of Darling.
 *
 * Copyright (C) 2022 Darling developers
 *
 * Darling is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * Darling is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Darling.  If not, see <http://www.gnu.org/licenses/>.
 */

/*
 * darling-lol M58F35:
 *
 * CATransformLayer was a stub NSObject whose forwardInvocation: merely logged
 * "Stub called: …".  Chromium (and AppKit) use CATransformLayer as a real layer
 * inside the layer tree, so CALayer's recursive -_setContext:/-_setSuperLayer:
 * and CALayer's/Chromium's -insertSublayer:atIndex: were dispatched to the stub
 * and did nothing; the runtime's forward-signature check also emitted ~49k
 * "NSForwardSignatureError: invoked with 3 args, but 2 expected" lines per run.
 * The result was a broken layer tree (context never propagated to the
 * transform-layer subtree — the compositor's frame never reached the tree).
 *
 * A CATransformLayer IS a CALayer (it only adds an is-3D flag and renders its
 * sublayers in 3D); on macOS it responds to the whole CALayer surface.  Deriving
 * it from CALayer therefore restores the correct behaviour for every selector
 * that was previously swallowed by the stub.
 */

#import <QuartzCore/CALayer.h>
#import <QuartzCore/CATransformLayer.h>

@implementation CATransformLayer
@end
