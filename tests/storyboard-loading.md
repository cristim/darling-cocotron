# NSStoryboard loading

`storyboard-loading.py DIR` writes `DIR/Fixture.storyboardc`, a compiled storyboard laid out the way
`ibtool` lays one out: an `Info.plist` with `NSStoryboardDesignatedEntryPointIdentifier` and
`NSViewControllerIdentifiersToNibNames`, and one keyed-archive nib per scene, written by `nibfixture.py`. The Detail scene keeps
its view in a separate nib inside the storyboard, named by the controller's `NSNibName`.

Build `storyboard-loading.m` as a standalone Objective-C executable linked with AppKit and Foundation
using the Darling SDK, copy the fixture into the prefix, and run `storyboard-loading DIR` in a Darling
guest. It needs no display connection.

The test loads the storyboard from a bundle, instantiates the initial window controller and a view
controller by identifier, checks their `storyboard`, loads the view controller's view from the
storyboard, checks that a scene's external object placeholder is replaced by the storyboard, and
checks that a scene returns its root controller when its child or window content
controller is also top level, and checks the exceptions for a missing storyboard,
an unknown identifier, a missing nib and two independent controllers. The expected result is
`storyboard loading checks=19 failures=0`. The pre-fix library has no `+storyboardWithName:bundle:`,
so the first call raises.
