# NSTextContainer width must constrain line layout

Build nstypesetter-container-width.m against AppKit and Foundation. Run it with no
compositor and no Apple application: it only measures strings.

The typesetter used to seed its scan rect with a fixed width of 1e7 and to reset
it to 1e7 on every new line, so the text container's width never constrained
line layout and every string measured as one line. A caller that sizes text to a
proposal - which OpenSwiftUI's `Text` does on every layout pass - then got back
a width larger than the space it offered, laid the text out centred on that
width, and ended up with a display-list item whose origin sat off the left edge
of its container. That is the left-clipped "FIRST TIME SETUP" / "Welcome to
AppZapper 3000" text in AppZapper's first-run window.

The probe asserts the AppKit contract instead:

- a finite container width wraps, so the measured width is at most the container
  width and the height grows past one line;
- a zero (unconstrained) size still returns a single line at the natural width;
- a container wider than the text leaves the text alone;
- a string that already fits is unchanged by the constraint;
- the private `boundingRectWithSize:options:context:` entry point, the one
  OpenSwiftUI calls, agrees.

Exit codes: 0 pass, 1 constrained width still exceeds the container, 2 the
constraint did not add a line, 3 an unconstrained measurement stopped returning
one line, 4 a short string was altered, 5 the private entry point disagrees.
