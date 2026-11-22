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
`tests/`. It has to be built without ARC, and it has to link and load a CoreGraphics
that exports the accessors, because the framework in the prefix predates them.

### Prerequisites

- `SDK` is an SDK whose `CoreGraphics.framework/Headers/CGGradient.h` is this
  repository's header, since the accessors the last case calls have to be declared
  before the test will compile. Copy the header in rather than using a stale one:

      cp CoreGraphics/include/CoreGraphics/CGGradient.h \
         "$SDK/System/Library/Frameworks/CoreGraphics.framework/Headers/CGGradient.h"

  run from the repository root; only the destination path matters.

- The library under test has to exist before the test is linked, or the link cannot
  resolve the accessors. It is built from this repository's `CoreGraphics/CGGradient.m`
  and the two `CGContextDraw*Gradient` entry points extracted from `CGContext.m`, and
  installed into the prefix as `usr/local/lib/libAZGradientFix.dylib`. Building the
  real CoreGraphics.framework is not possible from this checkout, so the
  implementation under test is loaded as that library, whose symbols take precedence
  over the installed framework. Whatever build step produces it is a prerequisite of
  the run below, not part of it.

### Build, link, run

    clang -c -target arm64-apple-macos13.0 -isysroot "$SDK" \
        -F "$SDK/System/Library/Frameworks" -o test.o tests/coregraphics-gradient.c
    ld -e _main -arch arm64 -platform_version macos 13.0 13.0 -syslibroot "$PREFIX" \
        -F "$PREFIX/System/Library/Frameworks" -rpath /usr/lib -flat_namespace \
        "$PREFIX/usr/local/lib/libAZGradientFix.dylib" \
        -framework Foundation -framework AppKit -framework QuartzCore \
        -framework CoreGraphics "$PREFIX/usr/lib/libSystem.B.dylib" -o test test.o
    DYLD_INSERT_LIBRARIES=/usr/local/lib/libAZGradientFix.dylib \
        test /usr/local/lib/libAZGradientFix.dylib

**The link must not pass `-undefined suppress`.** That flag turns an unresolved
accessor into a null symbol instead of a link error, so a CoreGraphics without the
accessors links cleanly and then calls through a null pointer. Measured here: with
the flag the link succeeds even though all five accessors are unresolvable, and
without it the same link fails with "Undefined symbols". Dropping the flag is what
makes the link part of the test.

The library path is passed to the program as its first argument, and the program
checks that it is really the library being used: each of the five accessors is
resolved once from that library with `dlopen`/`dlsym` and once from the process with
`dlsym(RTLD_DEFAULT, ...)`, and both have to be the same non-null address. A symbol
that came from the system framework, or that did not resolve, fails the run before
any pixel is compared, rather than being discovered as a null call. A run whose
accessors are not bound this way exits 12.

The `colors` case also covers that an array element which is not a colour is refused
rather than read as one, and the `accessors` case covers that the public getters
report what the gradient was actually created with. That makes eight cases. Without
the gradient implementation all of them fail, because
`CGGradientCreateWithColorComponents` returns NULL. Representative output with the
implementation loaded:

Abridged: the per-case pixel lines below are the ones worth reading, and the list is
not the program's complete output. The nine checks it runs, in order, are:

    ok   accessors bound to the library under test
    ok   components
    ok   colors
    ok   linear interpolation
    ok   locations
    ok   radial falloff
    ok   extend options
    ok   clip
    ok   accessors
    all gradient tests passed

The pixel detail those checks print:

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

## Known limitations

**The test runs against an injected library, not a full CoreGraphics build.**
cocotron's CoreGraphics cannot be rebuilt from this checkout: the private build's
ninja reads its headers from a tree outside the reachable paths, and those headers
are not copied anywhere available. So the implementation under test is loaded as
`libAZGradientFix.dylib`, built from this repository's `CoreGraphics/CGGradient.m`
plus the two `CGContextDraw*Gradient` entry points extracted from `CGContext.m`, and
its symbols take precedence over the installed `CoreGraphics.framework` in the
prefix. What that does and does not cover:

- It does cover the gradient code itself: the CF object, the accessors, the stop
  clamping, the interpolation, the CGFunction over the stops, the shading geometry,
  the extend flags and the class check, all of which come from this repository.
- It does not cover the framework around it. Anything the drawing path reaches that
  is not in those two files is the *installed* framework's, so a regression in
  `CGShadingCreateAxial`, in `O2Paint_ramp`, in `CGFunctionCreate` or in
  `NSApplication`'s bitmap-context path would not be attributed correctly by a run of
  this test. The gradient changes would be blamed for a failure that is actually
  upstream of them.
- A full build is the only way to close that. Until one is possible, treat a green
  run here as evidence about the gradient code and not about the framework.

**The non-colour refusal is over-determined.** `CGGradientCreateWithColors` refuses
an element that is not a colour, and the test shows it does, but it cannot show
*which* check refused it: the type check and the component-count check both fire on
the same input, because the latter reads a component count off an object that is not
a colour. Measured: removing the type check leaves all nine checks passing, so the
string is still refused by the component-count check. The two controls in the case
bound this down as far as they can, a two-colour array and a real CMYK colour with
the wrong component count are both handled as expected, which shows the type check
does not refuse a well-formed colour, but they do not separate the two refusals.
Separating them would need a colour whose component count happens to match, built
somewhere the check cannot inspect, which this CoreGraphics cannot express.
