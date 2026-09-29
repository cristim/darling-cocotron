# Gradient regression

Covers the three things a gradient has to get right, through the public API and by
reading back pixels, so an implementation that keeps the API shape but paints a
flat fill still fails: colour components (stops built from components and from
CGColors carry the components they were given, and a one-stop gradient paints that
colour), interpolation along a linear gradient (the colour varies between the stops
and lands between them at the axis midpoint, and a location array shifts where the
first stop appears), and radial falloff (the colour depends on the distance from the
centre rather than on x or y alone). It also covers the two drawing options that
decide whether the gradient paints before its start and after its end, and that
painting is limited to the current clip.

## Running it

cocotron has no wired test target, so this is a standalone program, like the rest of
`tests/`. It is a C file, so it has to be built without ARC, and it has to link and
load a CoreGraphics that actually exports the gradient API. The three steps below are
the ones the recorded output below came from; `SDK` is an SDK whose
`CoreGraphics.framework/Headers/CGGradient.h` is this repository's header, so the
accessors the last case calls are declared.

    clang -c -target arm64-apple-macos13.0 -isysroot "$SDK" \
        -F "$SDK/System/Library/Frameworks" -o test.o tests/coregraphics-gradient.c
    ld -e _main -arch arm64 -platform_version macos 13.0 13.0 -syslibroot "$PREFIX" \
        -F "$PREFIX/System/Library/Frameworks" -rpath /usr/lib -flat_namespace \
        -undefined suppress "$PREFIX/usr/local/lib/libAZGradientFix.dylib" \
        -framework Foundation -framework AppKit -framework QuartzCore \
        -framework CoreGraphics "$PREFIX/usr/lib/libSystem.B.dylib" -o test test.o
    DYLD_INSERT_LIBRARIES=/usr/local/lib/libAZGradientFix.dylib test

The test verifies the second and third steps itself rather than trusting them: the
`accessors` case calls `CGGradientGetTypeID`, and the program only links if
`CGGradientGetCount`, `CGGradientGetLocations`, `CGGradientGetColors` and
`CGGradientGetColorSpace` resolve. A CoreGraphics without them fails to link, and one
whose `CGGradientGetTypeID` returns 0 fails at runtime, so a green run cannot come
from a framework that never had the accessors.

The `colors` case also covers that an array element which is not a colour is refused
rather than read as one, and the `accessors` case covers that the public getters
report what the gradient was actually created with. That makes eight cases. Without
the gradient implementation all of them fail, because
`CGGradientCreateWithColorComponents` returns NULL. Representative output with the
implementation loaded:

    single stop, centre: 0,0,255,255
    colours: start: 255,0,0,255
    colours: end: 0,255,0,255
    linear: start: 255,0,0,255
    linear: middle: 128,0,128,255
    linear: end: 0,0,255,255
    locations: start: 255,0,0,255
    locations: middle: 255,0,0,255
    locations: end: 0,0,255,255
    radial: centre: 242,0,13,255
    radial: inner: 118,0,137,255
    radial: outer: 9,0,246,255
    radial: corner: 0,0,0,0
    extend: before start: 255,0,0,255
    extend: after end: 0,0,255,255
    clip: inside: 223,0,32,255
    clip: outside: 0,0,0,0
    accessors: count 2, locations 0.25,0.75

Each case also counts distinct colours along the axis, so a gradient that returns
one colour everywhere is reported as a flat fill.

Geometry is in CoreGraphics user space, where y grows upward, while a bitmap's first
row is its top row, and a pixel's centre sits at a half-integer coordinate. The
tests convert once in a helper, and the axes run between pixel centres, so the stops
land on painted pixels rather than half a pixel outside them. The bitmap is
premultiplied-first and 32-bit little-endian, the layout tests/image-resampling.m
already relies on.

The colours are interpolated per stop, at the locations the caller gave, and are not
sampled at a fixed rate: a two-stop gradient with locations 0.5 and 1.0 holds the
first colour from the axis start to its midpoint and blends only above it.
