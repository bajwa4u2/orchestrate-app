import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// A name for the machine a person is signing in from.
///
/// EVERY TRUSTED DEVICE WAS CALLED "CURRENT DEVICE".
///
/// The client sent that literal string at all five sign-in call sites, so every
/// device a person ever trusted, on every machine, carried the same name. On a
/// Pixel the security surface listed six rows reading "Current device · Active"
/// and nothing else — six identical answers to "where am I signed in?", and no
/// way to tell which one a Revoke would end.
///
/// A device list that cannot distinguish its devices is not a security control.
/// It is a list of buttons that do something to one of six things.
///
/// Derived without a plugin, because the useful part is which machine this is,
/// not a precise model string. Nothing here identifies a person: it is the
/// platform and, where the OS offers it, a short version.
String describeThisDevice() {
  if (kIsWeb) return 'Web browser';

  try {
    final os = switch (defaultTargetPlatform) {
      TargetPlatform.android => 'Android',
      TargetPlatform.iOS => 'iPhone',
      TargetPlatform.macOS => 'Mac',
      TargetPlatform.windows => 'Windows',
      TargetPlatform.linux => 'Linux',
      TargetPlatform.fuchsia => 'Fuchsia',
    };

    // operatingSystemVersion is long and inconsistent across platforms — on
    // Android it is a build fingerprint. Take the first meaningful fragment
    // rather than showing somebody a kernel string.
    final version = _shortVersion(Platform.operatingSystemVersion);
    return version.isEmpty ? os : '$os $version';
  } catch (_) {
    // Platform is unavailable in some hosts. A generic name is still better
    // than five call sites agreeing on the same literal.
    return 'This device';
  }
}

String _shortVersion(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return '';

  // Android reports "13 (API 33)"; Windows reports a long build description;
  // macOS reports "Version 14.5 (Build 23F79)". A leading version number is
  // the part that means anything to a person reading a device list.
  final match = RegExp(r'(\d+(?:\.\d+)*)').firstMatch(trimmed);
  return match?.group(1) ?? '';
}
