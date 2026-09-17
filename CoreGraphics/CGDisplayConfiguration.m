#import <CoreGraphics/CGDisplayConfiguration.h>
#import <CoreGraphics/CGDirectDisplay.h>
#import <stdlib.h>
#import <string.h>

struct _CGDisplayConfigRef {
    int dummy;
};

CGError CGDisplayRegisterReconfigurationCallback(CGDisplayReconfigurationCallBack callback, void *userInfo) {
    return kCGErrorSuccess;
}

CGError CGDisplayRemoveReconfigurationCallback(CGDisplayReconfigurationCallBack callback, void *userInfo) {
    return kCGErrorSuccess;
}

CGError CGBeginDisplayConfiguration(CGDisplayConfigRef *config) {
    if (config) {
        *config = (CGDisplayConfigRef)calloc(1, sizeof(struct _CGDisplayConfigRef));
    }
    return kCGErrorSuccess;
}

CGError CGCancelDisplayConfiguration(CGDisplayConfigRef config) {
    if (config) {
        free(config);
    }
    return kCGErrorSuccess;
}

CGError CGCompleteDisplayConfiguration(CGDisplayConfigRef config, CGConfigureOption option) {
    if (config) {
        free(config);
    }
    return kCGErrorSuccess;
}

CGError CGConfigureDisplayOrigin(CGDisplayConfigRef config, CGDirectDisplayID display, int32_t x, int32_t y) {
    return kCGErrorSuccess;
}

CGError CGConfigureDisplayMirrorOfDisplay(CGDisplayConfigRef config, CGDirectDisplayID display, CGDirectDisplayID master) {
    return kCGErrorSuccess;
}

// CGS private APIs
typedef union {
    uint8_t rawData[0xDC];
    struct {
        uint32_t mode;
        uint32_t flags;     // 0x4
        uint32_t width;     // 0x8
        uint32_t height;    // 0xC
        uint32_t depth;     // 0x10
        uint32_t dc2[42];
        uint16_t dc3;
        uint16_t freq;      // 0xBC
        uint32_t dc4[4];
        float density;      // 0xD0
    } derived;
} modes_D4;

void CGSGetCurrentDisplayMode(CGDirectDisplayID display, int *modeNum) {
    if (modeNum) {
        *modeNum = 0;
    }
}

void CGSGetNumberOfDisplayModes(CGDirectDisplayID display, int *nModes) {
    if (nModes) {
        *nModes = 1;
    }
}

void CGSGetDisplayModeDescriptionOfLength(CGDirectDisplayID display, int idx, void *mode, int length) {
    if (!mode || length <= 0) {
        return;
    }
    memset(mode, 0, length);
    modes_D4 m;
    memset(&m, 0, sizeof(m));
    m.derived.mode = idx;
    m.derived.flags = 0x03; // valid + safe
    m.derived.width = (uint32_t)CGDisplayPixelsWide(display);
    if (m.derived.width == 0) m.derived.width = 1920;
    m.derived.height = (uint32_t)CGDisplayPixelsHigh(display);
    if (m.derived.height == 0) m.derived.height = 1080;
    m.derived.depth = 32;
    m.derived.freq = 60;
    m.derived.density = 1.0f;

    size_t copyLen = (length < (int)sizeof(modes_D4)) ? length : sizeof(modes_D4);
    memcpy(mode, &m, copyLen);
}


void CGSConfigureDisplayMode(CGDisplayConfigRef config, CGDirectDisplayID display, int modeNum) {
}

CGError CGSConfigureDisplayEnabled(CGDisplayConfigRef config, CGDirectDisplayID display, bool enabled) {
    return kCGErrorSuccess;
}

