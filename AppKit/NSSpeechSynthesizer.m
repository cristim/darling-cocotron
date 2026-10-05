/*
 This file is part of Darling.

 Copyright (C) 2019 Lubos Dolezel

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

#import <AppKit/NSSpeechSynthesizer.h>

NSVoiceGenderName const NSVoiceGenderFemale = @"VoiceGenderFemale";
NSVoiceGenderName const NSVoiceGenderMale = @"VoiceGenderMale";

NSVoiceAttributeKey const NSVoiceName = @"VoiceName";
NSVoiceAttributeKey const NSVoiceGender = @"VoiceGender";
NSVoiceAttributeKey const NSVoiceDemoText = @"VoiceDemoText";
NSVoiceAttributeKey const NSVoiceLocaleIdentifier = @"VoiceLocaleIdentifier";

NSSpeechPropertyKey const NSSpeechRateProperty = @"rate";
NSSpeechPropertyKey const NSSpeechPitchBaseProperty = @"pbas";
NSSpeechPropertyKey const NSSpeechVolumeProperty = @"volm";

@implementation NSSpeechSynthesizer

/*
 * Chess.app sends +availableVoices while opening its untitled board window, from
 * -[NSDocumentController openUntitledDocumentAndDisplay:error:]. It died with
 * "+[NSSpeechSynthesizer availableVoices]: unrecognized selector sent to instance", because
 * the class existed but nothing implemented that class method, and the two forwarding methods
 * below only cover instance messages: a class message goes to the metaclass, which inherits
 * NSObject's unimplemented-selector path.
 *
 * There is no speech synthesis here, so the accurate answer is that there are no voices. An
 * empty array rather than nil, because a caller that indexes into the result is then correct
 * instead of crashing, and a caller that only counts sees zero either way.
 */
+ (NSArray *)availableVoices
{
    return [NSArray array];
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector
{
    return [NSMethodSignature signatureWithObjCTypes: "v@:"];
}

- (void)forwardInvocation:(NSInvocation *)anInvocation
{
    NSLog(@"Stub called: %@ in %@", NSStringFromSelector([anInvocation selector]), [self class]);
}

@end
