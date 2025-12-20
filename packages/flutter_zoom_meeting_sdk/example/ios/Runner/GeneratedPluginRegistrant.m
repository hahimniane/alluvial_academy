//
//  Generated file. Do not edit.
//

// clang-format off

#import "GeneratedPluginRegistrant.h"

#if __has_include(<flutter_zoom_meeting_sdk/FlutterZoomMeetingSdkPlugin.h>)
#import <flutter_zoom_meeting_sdk/FlutterZoomMeetingSdkPlugin.h>
#else
@import flutter_zoom_meeting_sdk;
#endif

#if __has_include(<integration_test/IntegrationTestPlugin.h>)
#import <integration_test/IntegrationTestPlugin.h>
#else
@import integration_test;
#endif

@implementation GeneratedPluginRegistrant

+ (void)registerWithRegistry:(NSObject<FlutterPluginRegistry>*)registry {
  [FlutterZoomMeetingSdkPlugin registerWithRegistrar:[registry registrarForPlugin:@"FlutterZoomMeetingSdkPlugin"]];
  [IntegrationTestPlugin registerWithRegistrar:[registry registrarForPlugin:@"IntegrationTestPlugin"]];
}

@end
