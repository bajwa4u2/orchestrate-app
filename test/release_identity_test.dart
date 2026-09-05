import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:orchestrate_app/core/release/release_identity.dart';

/// VERSION AND RATE ARE RELEASE INFRASTRUCTURE, NOT DECORATION.
///
/// Two mistakes are easy here and both were available. A hardcoded version
/// string drifts from the build that was actually uploaded, and support then
/// chases the wrong one. A Rate button on a platform with no listing either
/// goes nowhere or sends someone to a store they are not using.
void main() {
  final pubspec = File('pubspec.yaml').readAsStringSync();
  final release = File('lib/core/release/release_identity.dart').readAsStringSync();

  String? field(String key) {
    final match = RegExp('^\\s*$key:\\s*(\\S+)', multiLine: true).firstMatch(pubspec);
    return match?.group(1);
  }

  test('every customer-visible version reconciles', () {
    // pubspec is the single source: Android and iOS both derive from it
    // through flutter.versionName / FLUTTER_BUILD_NAME, and MSIX is the one
    // that has to be written down separately — which is exactly why it drifted
    // to 0.2.2.0 while everything else said 0.2.3.
    final version = field('version');
    expect(version, isNotNull);
    final parts = version!.split('+');
    final marketing = parts.first;
    final build = parts.length > 1 ? parts[1] : '';

    final msix = field('msix_version');
    expect(msix, isNotNull, reason: 'the Windows package states its own version');
    expect(
      msix!.startsWith('$marketing.'),
      isTrue,
      reason: 'Windows says $msix while the product says $marketing',
    );
    expect(
      msix.endsWith('.0'),
      isTrue,
      reason: 'the Microsoft Store requires the revision to be zero',
    );
    expect(build.isNotEmpty, isTrue, reason: 'a store upload needs a build number');
  });

  test('no version string is written down in the source', () {
    // The one place a version may appear in Dart is a test asserting it does
    // not. Anything else is a promise somebody has to remember to keep.
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      for (final match in RegExp(r"'\d+\.\d+\.\d+'").allMatches(source)) {
        offenders.add('${entity.uri.pathSegments.last}: ${match.group(0)}');
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: 'a version in the source drifts from the build that shipped:\n'
          '${offenders.join('\n')}',
    );
  });

  test('the version comes from the platform, once', () {
    expect(release.contains('PackageInfo.fromPlatform'), isTrue);
    expect(release.contains('_cached'), isTrue,
        reason: 'every surface must show the same answer');
    // A build that cannot read its own version says so rather than failing.
    expect(release.contains('isUnknown'), isTrue);
  });

  test('rate exists only where there is somewhere to rate', () {
    // Web has no listing. Windows holds a Partner Center product-identity
    // reservation, which is not a published listing and has no product id to
    // open — inventing one would send people somewhere that is not ours.
    // Scoped to the destination function. `currentPlatform` names Windows
    // because feedback from a Windows client must say so; that is a different
    // question from whether Windows has somewhere to be rated.
    final destination = release.substring(
      release.indexOf('static Uri? ratingDestination()'),
      release.indexOf('static String? ratingStoreName()'),
    );
    expect(destination.contains('if (kIsWeb) return null;'), isTrue);
    expect(
      destination.contains('TargetPlatform.windows'),
      isFalse,
      reason: 'Windows must fall through to null until a listing exists',
    );
    expect(destination.contains('default:'), isTrue);
    // And the real listings, not guesses.
    expect(release.contains('6772025079'), isTrue, reason: 'the live App Store id');
    expect(release.contains('com.orchestrateops.app'), isTrue,
        reason: 'the package the Play listing is keyed on');
  });

  test('the Apple id and Android package match what is shipped', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    expect(gradle.contains('com.orchestrateops.app'), isTrue,
        reason: 'the Rate link must open the package we actually ship');
  });
}
