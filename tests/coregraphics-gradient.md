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

Run it against CoreGraphics. Without the gradient implementation all seven cases
fail, because `CGGradientCreateWithColorComponents` returns NULL. With it, all seven
pass. Representative output with the implementation loaded:

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
