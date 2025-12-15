import Flutter
import MobileRTC
import UIKit

public class FlutterZoomMeetingSdkPlugin: NSObject, FlutterPlugin {
    var eventSink: FlutterEventSink?
    var isInitialized: Bool = false

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "flutter_zoom_meeting_sdk",
            binaryMessenger: registrar.messenger()
        )
        let instance = FlutterZoomMeetingSdkPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)

        // Register event channels
        let eventChannel = FlutterEventChannel(
            name: "flutter_zoom_meeting_sdk/events",
            binaryMessenger: registrar.messenger()
        )
        eventChannel.setStreamHandler(
            FlutterZoomEventStreamHandler(plugin: instance)
        )

    }

    func setEventSink(_ eventSink: FlutterEventSink?) {
        self.eventSink = eventSink
    }

    public func handle(
        _ call: FlutterMethodCall,
        result: @escaping FlutterResult
    ) {
        let action = call.method

        switch action {

        case "initZoom":
            if isInitialized == true {
                result(
                    makeActionResponse(
                        action: action,
                        isSuccess: true,
                        message: "MSG_INITIALIZED",
                    )
                )
                return
            }

            let context = MobileRTCSDKInitContext()
            context.domain = "zoom.us"

            let sdkInitializedSuccessfully = MobileRTC.shared().initialize(
                context
            )
            if sdkInitializedSuccessfully {
                isInitialized = true
            }

            result(
                makeActionResponse(
                    action: action,
                    isSuccess: sdkInitializedSuccessfully,
                    message: sdkInitializedSuccessfully
                        ? "MSG_INIT_SUCCESS"
                        : "MSG_INIT_FAILED",
                    params: [
                        "statusCode": sdkInitializedSuccessfully ? 0 : 1,
                        "statusLabel": sdkInitializedSuccessfully
                            ? "SUCCESS" : "FAILED",
                    ]
                )
            )

        case "authZoom":
            if isInitialized == false {
                result(
                    makeActionResponse(
                        action: action,
                        isSuccess: false,
                        message: "MSG_NO_YET_INITIALIZED",
                    )
                )
                return
            }

            guard let args = call.arguments as? [String: String] else {
                result(
                    makeActionResponse(
                        action: action,
                        isSuccess: false,
                        message: "MSG_NO_ARGS_PROVIDED",
                    )
                )
                return
            }

            guard let jwtToken = args["jwtToken"] else {
                result(
                    makeActionResponse(
                        action: action,
                        isSuccess: false,
                        message: "MSG_NO_JWT_TOKEN_PROVIDED",
                    )
                )
                return
            }

            let authorizationService = MobileRTC.shared().getAuthService()
            if let authService = authorizationService {
                authService.delegate = self
                authService.jwtToken = jwtToken
                authService.sdkAuth()
                result(
                    makeActionResponse(
                        action: action,
                        isSuccess: true,
                        message: "MSG_AUTH_SENT_SUCCESS",
                        params: [
                            "statusCode": 0,
                            "statusLabel": "SUCCESS",
                        ]
                    )
                )
            } else {
                result(
                    makeActionResponse(
                        action: action,
                        isSuccess: false,
                        message: "MSG_AUTH_SERVICE_NOT_FOUND",
                    )
                )
            }

        case "joinMeeting":
            if isInitialized == false {
                result(
                    makeActionResponse(
                        action: action,
                        isSuccess: false,
                        message: "MSG_NO_YET_INITIALIZED",
                    )
                )
                return
            }

            guard let args = call.arguments as? [String: String] else {
                result(
                    makeActionResponse(
                        action: action,
                        isSuccess: false,
                        message: "MSG_NO_ARGS_PROVIDED",
                    )
                )
                return
            }

            guard let meetingService = MobileRTC.shared().getMeetingService()
            else {
                result(
                    makeActionResponse(
                        action: action,
                        isSuccess: false,
                        message: "MSG_MEETING_SERVICE_NOT_AVAILABLE",
                    )
                )
                return
            }

            meetingService.delegate = self

            let joinMeetingParameters = MobileRTCMeetingJoinParam()

            joinMeetingParameters.meetingNumber = args["meetingNumber"]
            joinMeetingParameters.password = args["password"]
            joinMeetingParameters.userName = args["displayName"]
            joinMeetingParameters.webinarToken =
                (args["webinarToken"]?.isEmpty ?? true)
                ? nil : args["webinarToken"]
            joinMeetingParameters.noVideo = false
            joinMeetingParameters.noAudio = false

            let joinResult = meetingService.joinMeeting(
                with: joinMeetingParameters
            )

            result(
                makeActionResponse(
                    action: action,
                    isSuccess: joinResult == .success,
                    message: joinResult == .success
                        ? "MSG_JOIN_SENT_SUCCESS"
                        : "MSG_JOIN_SENT_FAILED",
                    params: [
                        "statusCode": joinResult.rawValue,
                        "statusLabel": joinResult.name,
                    ]
                )
            )

        case "unInitZoom":
            if isInitialized == false {
                result(
                    makeActionResponse(
                        action: action,
                        isSuccess: false,
                        message: "MSG_NO_YET_INITIALIZED",
                    )
                )
                return
            }

            MobileRTC.shared().cleanup()
            isInitialized = false
            result(
                makeActionResponse(
                    action: action,
                    isSuccess: true,
                    message: "MSG_UNINIT_SUCCESS"
                )
            )

        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
