#import <CoreFoundation/CoreFoundation.h>
#import <CoreGraphics/CGDirectDisplay.h>
#import <CoreGraphics/CGGeometry.h>

typedef CF_OPTIONS(uint32_t, CGDisplayChangeSummaryFlags) {
	kCGDisplayBeginConfigurationFlag  = (1 << 0),
	kCGDisplayMovedFlag               = (1 << 1),
	kCGDisplaySetMainFlag             = (1 << 2),
	kCGDisplaySetModeFlag             = (1 << 3),
	kCGDisplayAddFlag                 = (1 << 4),
	kCGDisplayRemoveFlag              = (1 << 5),
	kCGDisplayEnabledFlag             = (1 << 8),
	kCGDisplayDisabledFlag            = (1 << 9),
	kCGDisplayMirrorFlag              = (1 << 10),
	kCGDisplayUnMirrorFlag            = (1 << 11),
	kCGDisplayDesktopShapeChangedFlag = (1 << 12),
};

typedef void (*CGDisplayReconfigurationCallBack)(CGDirectDisplayID display, CGDisplayChangeSummaryFlags flags, void *userInfo);

extern CGError CGDisplayRegisterReconfigurationCallback(CGDisplayReconfigurationCallBack callback, void *userInfo);
extern CGError CGDisplayRemoveReconfigurationCallback(CGDisplayReconfigurationCallBack callback, void *userInfo);

typedef struct _CGDisplayConfigRef *CGDisplayConfigRef;

typedef uint32_t CGConfigureOption;
enum {
	kCGConfigureForAppOnly = 0,
	kCGConfigureForSession = 1,
	kCGConfigurePermanently = 2
};

COREGRAPHICS_EXPORT CGError CGBeginDisplayConfiguration(CGDisplayConfigRef *config);
COREGRAPHICS_EXPORT CGError CGCancelDisplayConfiguration(CGDisplayConfigRef config);
COREGRAPHICS_EXPORT CGError CGCompleteDisplayConfiguration(CGDisplayConfigRef config, CGConfigureOption option);
COREGRAPHICS_EXPORT CGError CGConfigureDisplayOrigin(CGDisplayConfigRef config, CGDirectDisplayID display, int32_t x, int32_t y);
COREGRAPHICS_EXPORT CGError CGConfigureDisplayMirrorOfDisplay(CGDisplayConfigRef config, CGDirectDisplayID display, CGDirectDisplayID master);

// CGS private APIs
COREGRAPHICS_EXPORT void CGSGetCurrentDisplayMode(CGDirectDisplayID display, int *modeNum);
COREGRAPHICS_EXPORT void CGSGetNumberOfDisplayModes(CGDirectDisplayID display, int *nModes);
COREGRAPHICS_EXPORT void CGSGetDisplayModeDescriptionOfLength(CGDirectDisplayID display, int idx, void *mode, int length);
COREGRAPHICS_EXPORT void CGSConfigureDisplayMode(CGDisplayConfigRef config, CGDirectDisplayID display, int modeNum);
COREGRAPHICS_EXPORT CGError CGSConfigureDisplayEnabled(CGDisplayConfigRef config, CGDirectDisplayID display, bool enabled);

