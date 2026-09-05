import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// PURPOSE STRINGS ARE ABOUT THE BINARY, NOT ABOUT OUR CODE.
///
/// All three of these were removed once, on the reasoning that the product
/// uses none of them — the only picker is `file_picker`, for a logo image and
/// a CSV of counterparties, and declaring a permission with no feature behind
/// it is a documented review rejection.
///
/// That reasoning was wrong in a way worth remembering. App Store Connect
/// rejected the upload with ITMS-90683 for the missing camera string, and
/// warned about location beside it. Apple analyses the shipped binary, and
/// `file_picker` links frameworks that reference those APIs whether or not a
/// line of our code calls them. Their own message says it: "While your app
/// might not use these APIs, a purpose string is still required."
///
/// The cost was a whole TestFlight cycle and a build number. This is here so
/// the next person with the same reasonable idea finds out from a test.
void main() {
  final plist = File('ios/Runner/Info.plist').readAsStringSync();

  const required = <String, String>{
    'NSCameraUsageDescription': 'ITMS-90683 rejected the upload without it',
    'NSPhotoLibraryUsageDescription': 'file_picker reaches the library for a logo',
    'NSLocationWhenInUseUsageDescription': 'App Store Connect warns without it',
  };

  required.forEach((key, why) {
    test('$key is declared', () {
      expect(plist.contains('<key>$key</key>'), isTrue, reason: why);
    });
  });

  test('each one says something, and says it specifically', () {
    for (final key in required.keys) {
      final at = plist.indexOf('<key>$key</key>');
      final value = plist.substring(at, plist.indexOf('</string>', at));
      final text = value.substring(value.indexOf('<string>') + 8).trim();
      expect(text.length, greaterThan(40),
          reason: '$key must explain itself to a person, not just exist');
      expect(text.toLowerCase().contains('orchestrate'), isTrue,
          reason: '$key must name the app it is speaking for');
    }
  });

  test('the export-compliance answer is still declared', () {
    // Without it every upload stops to ask, which is a manual step in a
    // pipeline that is meant not to need one.
    expect(plist.contains('ITSAppUsesNonExemptEncryption'), isTrue);
  });

  test('the privacy manifest is still in the bundle', () {
    expect(File('ios/Runner/PrivacyInfo.xcprivacy').existsSync(), isTrue);
    final project = File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();
    expect(project.contains('PrivacyInfo.xcprivacy in Resources'), isTrue,
        reason: 'a manifest that is not a build resource is not in the bundle');
  });
}
