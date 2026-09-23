#!/usr/bin/env python3
"""Write Fixture.storyboardc, a compiled storyboard for storyboard-loading.m, into the given directory.

A compiled storyboard is a directory with one nib per scene and an Info.plist naming the initial scene
and mapping scene identifiers to nib names. Each nib here is a keyed archive of an NSIBObjectData,
the form Cocotron's NSNib reads.
usage: storyboard-loading.py OUTPUT_DIR"""
import os
import plistlib
import sys


class Archive:
    def __init__(self):
        self.objects = ["$null"]
        self.classes = {}

    def add(self, value):
        self.objects.append(value)
        return plistlib.UID(len(self.objects) - 1)

    def cls(self, name, supers):
        if name not in self.classes:
            self.classes[name] = self.add({"$classname": name, "$classes": [name] + supers})
        return self.classes[name]

    def obj(self, name, supers, **fields):
        uid = self.add(None)
        self.objects[uid.data] = dict(fields, **{"$class": self.cls(name, supers)})
        return uid

    def array(self, items):
        return self.obj("NSArray", ["NSObject"], **{"NS.objects": list(items)})

    def data(self, top):
        return plistlib.dumps({"$archiver": "NSKeyedArchiver", "$version": 100000,
                               "$top": {"IB.objectdata": top}, "$objects": self.objects},
                              fmt=plistlib.FMT_BINARY)


RESPONDER = ["NSResponder", "NSObject"]


def nib(path, build):
    """build(archive, owner) returns (top-level objects, connections)."""
    a = Archive()
    owner = a.obj("NSCustomObject", ["NSObject"], NSClassName=a.add("NSObject"))
    top, connections = build(a, owner)
    data = a.obj("NSIBObjectData", ["NSObject"],
                 NSRoot=owner,
                 NSObjectsKeys=a.array(top), NSObjectsValues=a.array([owner] * len(top)),
                 NSNamesKeys=a.array([owner]), NSNamesValues=a.array([a.add("File's Owner")]),
                 NSConnections=a.array(connections),
                 NSVisibleWindows=a.obj("NSSet", ["NSObject"], **{"NS.objects": []}))
    with open(path, "wb") as f:
        f.write(a.data(data))


def window_scene(a, owner):
    return [a.obj("NSWindowController", RESPONDER)], []


def detail_scene(a, owner):
    controller = a.obj("FixtureViewController", ["NSViewController"] + RESPONDER,
                       NSNibName=a.add("Detail-view"), NSTitle=a.add("Detail"))
    return [controller], []


def detail_view(a, owner):
    view = a.obj("NSView", RESPONDER, NSFrame=a.add("{{0, 0}, {240, 120}}"))
    outlet = a.obj("NSNibOutletConnector", ["NSNibConnector", "NSObject"],
                   NSSource=owner, NSDestination=view, NSLabel=a.add("view"))
    return [view], [outlet]


def two_controllers(a, owner):
    return [a.obj("NSViewController", RESPONDER), a.obj("NSViewController", RESPONDER)], []


def main():
    out = os.path.join(sys.argv[1], "Fixture.storyboardc")
    os.makedirs(out, exist_ok=True)
    nib(os.path.join(out, "Window.nib"), window_scene)
    nib(os.path.join(out, "DetailController.nib"), detail_scene)
    nib(os.path.join(out, "Detail-view.nib"), detail_view)
    nib(os.path.join(out, "Ambiguous.nib"), two_controllers)
    with open(os.path.join(out, "Info.plist"), "wb") as f:
        plistlib.dump({"NSStoryboardDesignatedEntryPointIdentifier": "Window",
                       "NSStoryboardVersion": 1,
                       "NSViewControllerIdentifiersToNibNames": {
                           "Window": "Window", "Detail": "DetailController",
                           "Ambiguous": "Ambiguous", "Unbuilt": "Unbuilt"}}, f)


main()
