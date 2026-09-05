import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// WHICH BUILD THIS IS, FROM THE ONLY THING THAT KNOWS.
///
/// One authority for the version a person sees and the version a report
/// carries. Read from the package metadata the platform itself stamps at build
/// time — never from a constant in the source, because a constant is a promise
/// somebody has to remember to keep and nobody ever does. Aura shipped a build
/// whose visible version and uploaded build disagreed for exactly that reason.
///
/// The same values go into feedback, so a report can be tied to the build it
/// came from without asking the person to know what build they are running.
class ReleaseIdentity {
  const ReleaseIdentity({
    required this.version,
    required this.build,
    required this.packageName,
    required this.platform,
  });

  /// The marketing version: 0.2.3.
  final String version;

  /// The build number: 12. Increments per upload; the version need not.
  final String build;

  /// The package identity the store knows this by.
  final String packageName;

  /// Which client this is, in the words the backend's feedback domain uses.
  final String platform;

  /// What a person reads. "0.2.3 (12)" — the build is in brackets because it is
  /// what support will ask for and what the person will not otherwise know.
  String get label => build.isEmpty ? version : '$version ($build)';

  static ReleaseIdentity? _cached;

  /// Cached: the platform channel is asked once per run, and every surface
  /// that shows a version shows the same one.
  static Future<ReleaseIdentity> load() async {
    final cached = _cached;
    if (cached != null) return cached;
    try {
      final info = await PackageInfo.fromPlatform();
      return _cached = ReleaseIdentity(
        version: info.version.trim(),
        build: info.buildNumber.trim(),
        packageName: info.packageName.trim(),
        platform: currentPlatform,
      );
    } catch (_) {
      // Never fatal. A surface that cannot read its own version says so rather
      // than failing to render, and feedback still sends without it.
      return _cached = ReleaseIdentity(
        version: '',
        build: '',
        packageName: '',
        platform: currentPlatform,
      );
    }
  }

  /// True when the platform could not tell us. Rendered as "unknown" rather
  /// than as a number nobody should trust.
  bool get isUnknown => version.isEmpty;
}

/// The client this is running as, named the way the feedback domain names it.
String get currentPlatform {
  if (kIsWeb) return 'WEB';
  switch (defaultTargetPlatform) {
    case TargetPlatform.iOS:
      return 'IOS';
    case TargetPlatform.android:
      return 'ANDROID';
    case TargetPlatform.windows:
      return 'WINDOWS';
    case TargetPlatform.macOS:
      return 'MACOS';
    case TargetPlatform.linux:
      return 'LINUX';
    default:
      return 'UNKNOWN';
  }
}

/// WHERE THIS BUILD CAN LEGITIMATELY BE RATED.
///
/// Rating is a store action, so it only exists where there is a store listing
/// to send somebody to. Two ways to get this wrong, and both were available:
///
///   Show a Rate button on the web, where there is no listing, and it either
///   goes nowhere or goes to a store the person is not using.
///
///   Build a five-star widget of our own so that every platform can have a
///   Rate button. That collects nothing anybody reads and teaches people their
///   rating went somewhere it did not.
///
/// So: null is a real answer, and the surface renders nothing rather than
/// something.
class StoreListing {
  const StoreListing._();

  /// Apple's numeric id for Orchestrate Operations. Not a guess — this is the
  /// listing that is live.
  static const _appleAppId = '6772025079';

  /// The Android package the Play listing is keyed on.
  static const _androidPackage = 'com.orchestrateops.app';

  /// Where a person may rate this build, or null where no listing exists.
  ///
  /// WINDOWS IS DELIBERATELY NULL. Partner Center holds a product-identity
  /// reservation for Orchestrate Operations, and a reservation is not a
  /// published listing — there is no product id to open, and inventing one
  /// would send people to a page that is not ours or is not there. Windows
  /// gets no Rate action until the listing is live and its id is known.
  static Uri? ratingDestination() {
    if (kIsWeb) return null;
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return Uri.parse(
          'https://apps.apple.com/app/id$_appleAppId?action=write-review',
        );
      case TargetPlatform.android:
        return Uri.parse(
          'https://play.google.com/store/apps/details?id=$_androidPackage',
        );
      default:
        return null;
    }
  }

  /// The store this build was distributed by, for the label on the action.
  static String? ratingStoreName() {
    if (kIsWeb) return null;
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return 'the App Store';
      case TargetPlatform.android:
        return 'Google Play';
      default:
        return null;
    }
  }
}
