# Bilinear coverage precision regression

Build image-resampling.m against AppKit/Foundation using the Onyx2D headers. Run with `math` to exhaust all 256×256 input-value pairs and 257 complementary coverage weights. Expected: 16,842,752 checks, zero failures, including exact opaque alpha. This exercises the inline helper compiled into the test.

Run without arguments to draw a solid opaque NSBitmapImageRep through NSImage/NSCompositeCopy into premultiplied BGRA contexts at1×,2×,3×. The draw path uses the loaded Onyx2D framework. Interior pixels must remain (255,0,255,255). Use an installed baseline then the private candidate to distinguish test-header validation from framework validation. No compositor or Apple app is needed.

The correction adds weighted components before integer truncation, preserving constant colors and alpha across horizontal/vertical bilinear passes. It does not implement a different resampling filter or claim fractional-edge/presentation accuracy.
