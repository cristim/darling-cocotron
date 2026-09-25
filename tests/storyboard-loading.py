#!/usr/bin/env python3
"""Write Fixture.storyboardc, a compiled storyboard for storyboard-loading.m, into the given directory.

A compiled storyboard is a directory with one nib per scene and an Info.plist naming the initial scene
and mapping scene identifiers to nib names.
usage: storyboard-loading.py OUTPUT_DIR"""
import os
import plistlib
import sys

from nibfixture import RESPONDER, write_nib


def window_scene(a, owner):
    return [a.obj("NSWindowController", RESPONDER)], []


def detail_scene(a, owner):
    controller = a.obj("FixtureViewController", ["NSViewController"] + RESPONDER,
                       NSNibName=a.add("Detail-view"), NSTitle=a.add("Detail"))
    a.objects[controller.data]["NSExternalObjectsTableForViewLoading"] = a.obj(
        "NSDictionary", ["NSObject"], **{
            "NS.keys": [a.add("UpstreamPlaceholder-1")],
            "NS.objects": [controller],
        })
    return [controller], []


def detail_view(a, owner):
    view = a.obj("FixtureView", ["NSView"] + RESPONDER,
                 NSFrame=a.add("{{0, 0}, {240, 120}}"))
    placeholder = a.obj("NSNibExternalObjectPlaceholder", ["NSObject"],
                        NSExternalObjectPlaceholderIdentifier=a.add("UpstreamPlaceholder-1"))
    return [view, placeholder], [a.outlet(owner, view, "view"),
                                a.outlet(view, placeholder, "upstream")]


def placeholder_scene(a, owner):
    controller = a.obj("FixtureViewController", ["NSViewController"] + RESPONDER, NSTitle=a.add("Placeholder"))
    placeholder = a.obj("NSNibExternalObjectPlaceholder", ["NSObject"],
                        NSExternalObjectPlaceholderIdentifier=a.add("FixtureSceneObject"))
    return [controller, placeholder], [a.outlet(controller, placeholder, "representedObject")]


def two_controllers(a, owner):
    return [a.obj("NSViewController", RESPONDER), a.obj("NSViewController", RESPONDER)], []


def contained_view_controllers(a, owner):
    parent = a.obj("FixtureViewController", ["NSViewController"] + RESPONDER)
    child = a.obj("FixtureViewController", ["NSViewController"] + RESPONDER)
    return [parent, child], [a.outlet(parent, a.array([child]), "childViewControllers")]


def window_with_content_controller(a, owner):
    window = a.obj("FixtureWindowController", ["NSWindowController"] + RESPONDER)
    content = a.obj("FixtureViewController", ["NSViewController"] + RESPONDER)
    return [window, content], [a.outlet(window, content, "contentViewController")]


def window_with_unattached_controller(a, owner):
    window = a.obj("FixtureWindowController", ["NSWindowController"] + RESPONDER)
    content = a.obj("FixtureViewController", ["NSViewController"] + RESPONDER)
    return [window, content], []


def two_window_controllers(a, owner):
    return [a.obj("NSWindowController", RESPONDER),
            a.obj("NSWindowController", RESPONDER)], []


out = os.path.join(sys.argv[1], "Fixture.storyboardc")
os.makedirs(out, exist_ok=True)
write_nib(os.path.join(out, "Window.nib"), window_scene)
write_nib(os.path.join(out, "DetailController.nib"), detail_scene)
write_nib(os.path.join(out, "Detail-view.nib"), detail_view)
write_nib(os.path.join(out, "Ambiguous.nib"), two_controllers)
write_nib(os.path.join(out, "Contained.nib"), contained_view_controllers)
write_nib(os.path.join(out, "WindowWithContent.nib"), window_with_content_controller)
write_nib(os.path.join(out, "WindowWithUnattached.nib"), window_with_unattached_controller)
write_nib(os.path.join(out, "TwoWindows.nib"), two_window_controllers)
write_nib(os.path.join(out, "PlaceholderController.nib"), placeholder_scene)
with open(os.path.join(out, "Info.plist"), "wb") as f:
    plistlib.dump({"NSStoryboardDesignatedEntryPointIdentifier": "Window",
                   "NSStoryboardVersion": 1,
                   "NSViewControllerIdentifiersToNibNames": {
                       "Window": "Window", "Detail": "DetailController",
                       "Ambiguous": "Ambiguous", "Contained": "Contained",
                       "WindowWithContent": "WindowWithContent", "Unbuilt": "Unbuilt",
                       "WindowWithUnattached": "WindowWithUnattached",
                       "TwoWindows": "TwoWindows",
                       "Placeholder": "PlaceholderController"}}, f)
