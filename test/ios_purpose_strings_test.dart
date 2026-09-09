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

  test('shipping a purchase library means declaring purchase data', () {
    // The manifest listed four data types and not purchases, which was correct
    // while the app could not take a payment. It became wrong the moment
    // in_app_purchase shipped: the app hands StoreKit's signed transaction to
    // our server, and StorePurchaseEvidence keeps the product, the transaction,
    // the state and the expiry against the paying organisation. Apple's test
    // for "collect" is transmitting off the device and holding it beyond
    // servicing the request in real time — an entitlement record is exactly
    // that, and it is linked to identity.
    //
    // The App Store Connect declaration and this file are two statements of the
    // same fact, made in two places, and they drifted. This ties them together:
    // if the purchase library is in the graph, the manifest must say so.
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final shipsPurchases = pubspec.contains('in_app_purchase:');
    final manifest = File('ios/Runner/PrivacyInfo.xcprivacy').readAsStringSync();

    expect(
      shipsPurchases,
      isTrue,
      reason: 'this test assumes the purchase library ships; if it was removed '
          'on purpose, retire this test rather than weakening it',
    );
    expect(
      manifest.contains('NSPrivacyCollectedDataTypePurchaseHistory'),
      isTrue,
      reason: 'in_app_purchase ships in this binary, so the privacy manifest '
          'must declare purchase history — App Store Connect already does',
    );
  });

  test('nothing in the manifest claims tracking', () {
    // NSPrivacyTracking false, and no individual type marked as tracking.
    // Orchestrate follows nobody across other companies' apps, and the day
    // that stops being true it should stop being true here first.
    final manifest = File('ios/Runner/PrivacyInfo.xcprivacy').readAsStringSync();
    final trackingKey = manifest.indexOf('<key>NSPrivacyTracking</key>');
    expect(trackingKey, greaterThan(-1));
    expect(
      manifest.substring(trackingKey, trackingKey + 80).contains('<false/>'),
      isTrue,
      reason: 'NSPrivacyTracking must be false',
    );
    final trackedType = RegExp(
      r'NSPrivacyCollectedDataTypeTracking</key>\s*<true/>',
      multiLine: true,
    );
    expect(
      trackedType.hasMatch(manifest),
      isFalse,
      reason: 'no collected data type may be marked as used for tracking',
    );
  });
}
