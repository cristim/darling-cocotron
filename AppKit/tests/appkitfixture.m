/*
 * Minimal AppKit assertions that do not need a window server interaction path.
 *
 * cocotron had no runnable test target at all, and this exists because
 * -[NSTextAttachmentCell cellSize] was NSUnimplementedMethod() returning
 * (0, 0) while NSCell's base implementation deliberately returns a huge
 * clamping sentinel. An attachment cell reporting zero size makes text
 * attachments collapse to nothing, and Stickies calls drawWithFrame: on it
 * repeatedly.
 *
 * Build and run:
 *   ninja appkitfixture
 *   DARLING_APPKIT_BACKEND=wayland <darling> shell ./appkitfixture
 *
 * Keep this to things assertable without synthetic input; anything needing a
 * click or a keystroke does not belong here.
 */

#import <AppKit/AppKit.h>
#import <AppKit/NSTextAttachment.h>
#import <AppKit/NSTextAttachmentCell.h>

#include <stdio.h>

static int failures;

static void assertThat(int ok, const char *what)
{
	printf("%s %s\n", ok ? "CHECK PASS" : "CHECK FAIL", what);
	if (!ok) failures++;
}

int main(void)
{
	NSAutoreleasePool *pool = [NSAutoreleasePool new];

	/* A 20x12 image, so the expected cell size is unambiguous. */
	NSImage *image = [[NSImage alloc] initWithSize: NSMakeSize(20, 12)];
	NSTextAttachment *attachment = [[NSTextAttachment alloc] init];
	[attachment setImage: image];
	NSTextAttachmentCell *cell = [[NSTextAttachmentCell alloc] init];
	[cell setAttachment: attachment];

	NSSize size = [cell cellSize];
	printf("cellSize = %g x %g\n", size.width, size.height);
	/* Zero is the bug: it collapses the attachment to nothing. */
	assertThat(size.width > 0 && size.height > 0,
	      "attachment cell reports a non-zero size");

	/* With no image there is nothing to size, so it must fall back to the
	   NSCell clamping sentinel rather than reporting zero. */
	NSTextAttachment *bare = [[NSTextAttachment alloc] init];
	NSTextAttachmentCell *bareCell = [[NSTextAttachmentCell alloc] init];
	[bareCell setAttachment: bare];
	NSSize bareSize = [bareCell cellSize];
	assertThat(bareSize.width > 0 && bareSize.height > 0,
	      "attachment cell without an image still reports a non-zero size");

	/* Drawing must not raise now that it is implemented. */
	NSView *view = [[NSView alloc] initWithFrame: NSMakeRect(0, 0, 40, 20)];
	[cell drawWithFrame: NSMakeRect(0, 0, 20, 12)
	             inView: view
	   characterIndex: 0
	    layoutManager: nil];
	assertThat(YES, "drawWithFrame:inView:characterIndex:layoutManager: does not raise");

	printf("RESULT failures=%d\n", failures);
	[pool release];
	return failures ? 1 : 0;
}
