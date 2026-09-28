import CoreGraphics

// The Swift spellings OpenSwiftUI uses: CGColor.converted(to:intent:options:) and the HDR queries.
let extendedSRGB = CGColorSpace(name: kCGColorSpaceExtendedSRGB)!
let p3Red = CGColor(colorSpace: CGColorSpace(name: kCGColorSpaceDisplayP3)!, components: [1, 0, 0, 1])!
let converted = p3Red.converted(to: extendedSRGB, intent: .defaultIntent, options: nil)
let c = converted?.components ?? []
let pq = CGColorSpace(name: kCGColorSpaceITUR_2100_PQ)!
if c.count == 4 && abs(c[0] - 1.0931) < 1e-3 && abs(c[1] + 0.2267) < 1e-3 && abs(c[2] + 0.1501) < 1e-3
    && CGColorSpaceUsesITUR_2100TF(pq) && !CGColorSpaceUsesITUR_2100TF(extendedSRGB) && !CGColorSpaceIsHLGBased(pq) {
    print("ALL PASSED")
} else {
    print("FAIL: \(c)")
    exit(1)
}
