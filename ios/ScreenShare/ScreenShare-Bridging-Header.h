// MobileRTCScreenShare ships as an Objective-C framework with no Clang module
// map, so `import MobileRTCScreenShare` from Swift fails. Expose its header via
// this bridging header instead. Requires FRAMEWORK_SEARCH_PATHS to include the
// framework's ios-arm64 slice (set on the ScreenShare target).
#import <MobileRTCScreenShare/MobileRTCScreenShareService.h>
