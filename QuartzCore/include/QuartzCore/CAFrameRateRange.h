#ifndef CAFRAMERATERANGE_H
#define CAFRAMERATERANGE_H

// The frame rate range type (macOS 12). The three-float layout is ABI: callers built against the macOS SDK pass it
// by value, and Swift mangles it as So16CAFrameRateRangeV.
typedef struct CAFrameRateRange {
    float minimum;
    float maximum;
    float preferred;
} CAFrameRateRange;

#endif
