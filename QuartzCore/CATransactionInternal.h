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
 * along with Darling. If not, see <http://www.gnu.org/licenses/>.
 */

#import <QuartzCore/CATransaction.h>

@interface CATransaction (Internal)
// Whether a transaction the caller opened with +begin is still open. A property
// change is animated only inside one, so this gates the implicit actions. It is
// deliberately not "is the transaction stack non-empty": reading a transaction
// property also opens an implicit group, which is committed on a later run loop
// pass and would otherwise make every property change look animated.
+ (BOOL) hasOpenTransaction;
// Private. The state of the innermost open transaction, nil when none is open.
+ (id) currentState;
// Private. Keeps a handler for "an implicit transaction began"; never called, its signature is unknown.
+ (void) setImplicitTransactionDidBeginHandler: (id) handler;
// Private. Keeps a flag that asks a run loop observer not to commit transactions; has no effect here.
+ (void) setDisableRunLoopObserverCommits: (BOOL) value;
// Private. Keeps the default of that flag for later transactions; has no effect here.
+ (void) setDefaultDisableRunLoopObserverCommits: (BOOL) value;
@end
