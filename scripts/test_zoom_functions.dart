import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import '../lib/firebase_options.dart';

/// Small script to test Zoom cloud functions directly.
/// Run this with `flutter run scripts/test_zoom_functions.dart`
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  print('--- Testing Zoom Cloud Functions ---');

  final shiftId = '0k4MWrpEJhwKm4EcoWhR'; // From your logs
  final functions = FirebaseFunctions.instanceFor(region: 'us-central1');

  try {
    print('1. Testing getZoomMeetingSdkJoinPayload...');
    final payloadResult = await functions
        .httpsCallable('getZoomMeetingSdkJoinPayload')
        .call({'shiftId': shiftId});
    print('Payload Success: ${payloadResult.data}');
  } catch (e) {
    print('Payload Error: $e');
  }

  try {
    print('2. Testing getZoomHostKey...');
    final hostKeyResult = await functions
        .httpsCallable('getZoomHostKey')
        .call({'shiftId': shiftId});
    print('Host Key Success: ${hostKeyResult.data}');
  } catch (e) {
    print('Host Key Error: $e');
  }

  print('--- Test Complete ---');
}
