#import "RotationBridge.h"

#import <ApplicationServices/ApplicationServices.h>
#import <Foundation/Foundation.h>
#import <IOKit/IOKitLib.h>
#import <IOKit/graphics/IOGraphicsTypes.h>
#import <dlfcn.h>

// CGDisplayIOServicePort is still exported by ApplicationServices, but its
// declaration is no longer included in recent public SDK headers.
extern io_service_t CGDisplayIOServicePort(CGDirectDisplayID display);

@interface NSObject (RotatorMonitorPanel)
- (instancetype)initWithCGSDisplayID:(CGDirectDisplayID)displayID;
- (void)setOrientation:(NSInteger)orientation;
@end

static char rbLastError[512] = "";

static void RBSetError(NSString *message) {
    const char *utf8 = message.UTF8String ?: "Unknown display rotation error";
    snprintf(rbLastError, sizeof(rbLastError), "%s", utf8);
}

static int32_t RBSetUsingLegacyIOKit(CGDirectDisplayID displayID, int32_t degrees) {
    // kIOFBSetTransform is private; the transform bit values themselves are
    // published in IOGraphicsTypes.h.
    const IOOptionBits kIOFBSetTransform = 0x00000400;
    IOOptionBits transform;
    switch (degrees) {
        case 0: transform = kIOScaleRotate0; break;
        case 90: transform = kIOScaleRotate90; break;
        case 180: transform = kIOScaleRotate180; break;
        case 270: transform = kIOScaleRotate270; break;
        default: return 1;
    }

    io_service_t service = CGDisplayIOServicePort(displayID);
    if (service == MACH_PORT_NULL) {
        RBSetError(@"디스플레이의 IOKit 서비스를 찾지 못했습니다.");
        return 4;
    }

    kern_return_t result = IOServiceRequestProbe(
        service,
        kIOFBSetTransform | (transform << 16)
    );
    if (result != KERN_SUCCESS) {
        RBSetError([NSString stringWithFormat:@"IOKit 회전 요청이 실패했습니다. (0x%x)", result]);
        return 4;
    }
    return 0;
}

int32_t RBSetDisplayRotation(uint32_t displayID, int32_t degrees) {
    rbLastError[0] = '\0';
    if (displayID == 0 || (degrees != 0 && degrees != 90 && degrees != 180 && degrees != 270)) {
        RBSetError(@"잘못된 디스플레이 또는 회전 각도입니다.");
        return 1;
    }

    static dispatch_once_t onceToken;
    static void *monitorPanelHandle = NULL;
    dispatch_once(&onceToken, ^{
        monitorPanelHandle = dlopen(
            "/System/Library/PrivateFrameworks/MonitorPanel.framework/MonitorPanel",
            RTLD_LAZY | RTLD_LOCAL
        );
    });

    Class displayClass = NSClassFromString(@"MPDisplay");
    SEL initializer = NSSelectorFromString(@"initWithCGSDisplayID:");
    SEL setter = NSSelectorFromString(@"setOrientation:");

    if (monitorPanelHandle != NULL && displayClass != Nil &&
        [displayClass instancesRespondToSelector:initializer] &&
        [displayClass instancesRespondToSelector:setter]) {
        @try {
            id display = [[displayClass alloc] initWithCGSDisplayID:displayID];
            if (display == nil) {
                RBSetError(@"macOS가 디스플레이 객체를 만들지 못했습니다.");
                return 2;
            }
            [display setOrientation:degrees];
            return 0;
        } @catch (NSException *exception) {
            RBSetError(exception.reason ?: @"MonitorPanel 회전 요청 중 오류가 발생했습니다.");
            return 3;
        }
    }

    return RBSetUsingLegacyIOKit(displayID, degrees);
}

const char *RBLastErrorMessage(void) {
    return rbLastError;
}
