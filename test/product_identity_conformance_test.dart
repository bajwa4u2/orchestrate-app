import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// THE SHIPPED ICON IS THE PRODUCT'S IDENTITY, SO IT IS TESTED LIKE CODE.
///
/// Orchestrate's canonical mark is the cycle mark the Microsoft build carries:
/// white, on a NEUTRAL BLACK ground, with room to breathe around it.
///
/// It drifted once, and quietly. `tool/generate_store_assets.ps1` used to *draw*
/// a mark in code rather than resample the master, and what it drew was a
/// different logo entirely -- a two-arrow refresh glyph on a navy gradient with
/// a cyan accent. Every asset that tool wrote was therefore wrong, on every
/// platform, and nothing failed: the app built, the tests passed, the stores
/// accepted the uploads. The only surviving canonical copies were the handful
/// of files the tool happened never to overwrite.
///
/// Nothing about that failure was detectable from source. It is only visible in
/// the pixels, so this test looks at the pixels.
void main() {
  // Two signals separate the canonical mark from the drifted one without
  // needing to recognise shapes:
  //   * blueness -- the navy ground puts blue well above red/green; the
  //     canonical ground is neutral, so the difference is ~0
  //   * cyan     -- the accent exists ONLY in the drifted mark
  const maxBlueness = 8.0;
  const maxCyanFraction = 0.005;

  // The mark must actually be there, and must not fill the tile edge to edge.
  const minMarkFraction = 0.05;
  const minMarkSpan = 0.46;
  const maxMarkSpan = 0.66;

  // The master is deliberately cropped tighter than the tiles generated from
  // it; the breathing margin is added during generation. So the master is held
  // to the identity rules but not to the composition rule.
  const masters = <String>{
    'assets/branding/icons/orchestrate_app_icon_dark_1024.png',
  };

  const opaqueIcons = <String>[
    'assets/branding/icons/orchestrate_app_icon_dark_1024.png',
    'store_assets/source/orchestrate-app-icon-master-1024.png',
    'store_assets/android/play-icon-512.png',
    'store_assets/ios/app-store-icon-1024.png',
    'store_assets/windows/store-tile-300.png',
    'android/app/src/main/res/mipmap-mdpi/ic_launcher.png',
    'android/app/src/main/res/mipmap-hdpi/ic_launcher.png',
    'android/app/src/main/res/mipmap-xhdpi/ic_launcher.png',
    'android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png',
    'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png',
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png',
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png',
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@2x.png',
    'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png',
    'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_512.png',
    'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_256.png',
    'web/icons/Icon-512.png',
    'web/icons/Icon-192.png',
    'web/favicon.png',
  ];

  img.Image load(String path) {
    final file = File(path);
    expect(file.existsSync(), isTrue, reason: '$path is missing');
    final decoded = img.decodePng(file.readAsBytesSync());
    expect(decoded, isNotNull, reason: '$path did not decode');
    return decoded!;
  }

  for (final path in opaqueIcons) {
    test('$path carries the canonical mark', () {
      final image = load(path);

      var groundPixels = 0;
      var bluenessSum = 0.0;
      var cyanPixels = 0;
      var markPixels = 0;
      var minX = image.width, maxX = -1;

      for (var y = 0; y < image.height; y++) {
        for (var x = 0; x < image.width; x++) {
          final p = image.getPixel(x, y);
          final r = p.r.toDouble(), g = p.g.toDouble(), b = p.b.toDouble();
          final luminance = r + g + b;

          if (luminance < 400) {
            groundPixels++;
            bluenessSum += b - (r + g) / 2;
          }
          if (b > 150 && g > 130 && r < 130) {
            cyanPixels++;
          }
          if (luminance > 550) {
            markPixels++;
            if (x < minX) minX = x;
            if (x > maxX) maxX = x;
          }
        }
      }

      final total = image.width * image.height;
      final blueness = groundPixels == 0 ? 0.0 : bluenessSum / groundPixels;
      final cyanFraction = cyanPixels / total;
      final markFraction = markPixels / total;

      expect(blueness, lessThan(maxBlueness),
          reason: 'the ground is navy, not neutral black -- this is the '
              'drifted mark, or the drift palette has come back');
      expect(cyanFraction, lessThan(maxCyanFraction),
          reason: 'a cyan accent is present, which only the drifted mark has');
      expect(markFraction, greaterThan(minMarkFraction),
          reason: 'no white mark found -- the tile is effectively blank');

      // Small icons are too coarse for a meaningful span measurement.
      if (image.width >= 128 && !masters.contains(path)) {
        final span = (maxX - minX) / image.width;
        expect(span, greaterThan(minMarkSpan),
            reason: 'the mark is too small for its tile');
        expect(span, lessThan(maxMarkSpan),
            reason: 'the mark fills the tile edge to edge with no room to '
                'breathe -- it reads as contained rather than composed');
      }
    });
  }

  test('every platform shows the SAME mark, not merely a canonical-looking one',
      () {
    // Per-file checks cannot catch a platform quietly carrying a different
    // mark that happens to be white-on-black. Comparing each against the master
    // can.
    final master = img.copyResize(
      load('assets/branding/icons/orchestrate_app_icon_dark_1024.png'),
      width: 64,
      height: 64,
    );

    double coverage(img.Image image) {
      var n = 0;
      for (var y = 0; y < image.height; y++) {
        for (var x = 0; x < image.width; x++) {
          final p = image.getPixel(x, y);
          if (p.r + p.g + p.b > 550) n++;
        }
      }
      return n / (image.width * image.height);
    }

    final masterCoverage = coverage(master);
    for (final path in opaqueIcons) {
      final image = load(path);
      if (image.width < 128) continue;
      final scaled = img.copyResize(image, width: 64, height: 64);
      // Coverage differs by composition (the master is drawn tighter than the
      // tiles it generates), so this is a generous bound: it is here to catch a
      // wholly different logo, not to police a few percent.
      expect((coverage(scaled) - masterCoverage).abs(), lessThan(0.12),
          reason: '$path does not depict the same mark as the master');
    }
  });

  test('the vector master exists and is a real vector, for reuse', () {
    // The raster master is what the generator resamples, but a raster cannot be
    // reused at arbitrary size or recoloured for a light surface. The SVG is the
    // reusable form of the same mark.
    final svg = File('assets/branding/logo/orchestrate_mark.svg');
    expect(svg.existsSync(), isTrue);
    final body = svg.readAsStringSync();
    expect(body, contains('<svg'));
    expect(body, contains('<path'));
    expect(body, contains('currentColor'),
        reason: 'the reusable mark must take its colour from context');
    expect(body.contains('<image'), isFalse,
        reason: 'an SVG wrapping a bitmap is not a vector master');
  });
}
