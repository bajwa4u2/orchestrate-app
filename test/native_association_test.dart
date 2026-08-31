import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// AN ASSOCIATION FILE THAT ANSWERS 200 WITH HTML IS WORSE THAN A 404.
///
/// Before this, `https://orchestrateops.com/.well-known/assetlinks.json`
/// returned the Flutter SPA's `index.html` with HTTP 200: the file did not
/// exist, so nginx's `try_files ... /index.html` fallback answered for it.
/// Android fetches that URL itself and needs JSON, so App Links could never
/// verify — and every naive check passed, because the status code was 200.
///
/// So these tests assert the two things that actually make it work: the file
/// exists and is real JSON naming the right app, and the front door serves it
/// from disk with a 404 when it is missing rather than handing back the shell.
void main() {
  final assetlinks = File('web/.well-known/assetlinks.json');
  final nginx = File('nginx.conf');

  group('Android App Links', () {
    test('assetlinks.json exists and is JSON, not the SPA shell', () {
      expect(assetlinks.existsSync(), isTrue,
          reason: 'web/.well-known/assetlinks.json is missing, so the front '
              'door will fall through to index.html');

      final raw = assetlinks.readAsStringSync();
      expect(raw.trimLeft().startsWith('<'), isFalse,
          reason: 'this file is HTML — that is the defect, not the fix');

      final parsed = jsonDecode(raw); // throws if it is not JSON at all
      expect(parsed, isA<List>());
    });

    test('it names this app, with the Play app-signing certificate', () {
      final statements = jsonDecode(assetlinks.readAsStringSync()) as List;
      final target = (statements.first as Map)['target'] as Map;

      expect((statements.first as Map)['relation'],
          contains('delegate_permission/common.handle_all_urls'));
      expect(target['namespace'], 'android_app');
      expect(target['package_name'], 'com.orchestrateops.app');

      final prints = (target['sha256_cert_fingerprints'] as List).cast<String>();
      // The Play APP SIGNING key is the one installs are signed with, so it is
      // the one that must be present. The upload key is kept alongside it so a
      // locally-signed build verifies too, which is what makes testing honest.
      expect(
        prints,
        contains('41:1D:20:19:5F:4A:E7:8B:96:79:A4:59:7D:9C:AF:88:AF:D7:E0:BF:'
            '59:DE:E5:B0:52:07:5E:8A:59:52:DA:E3'),
        reason: 'the Play app-signing fingerprint is missing; installs from '
            'Play would fail verification',
      );
      for (final p in prints) {
        expect(RegExp(r'^([0-9A-F]{2}:){31}[0-9A-F]{2}$').hasMatch(p), isTrue,
            reason: '$p is not a SHA-256 fingerprint');
      }
    });

    test('the front door serves it from disk instead of the SPA fallback', () {
      final conf = nginx.readAsStringSync();
      expect(conf, contains('location = /.well-known/assetlinks.json'),
          reason: 'without its own location block the SPA fallback answers');
      // `try_files $uri =404` is the load-bearing half: it turns a missing
      // file into a 404 a validator can see, instead of a reassuring 200.
      final block = conf.substring(conf.indexOf('location = /.well-known/assetlinks.json'));
      expect(block.substring(0, block.indexOf('}')), contains(r'try_files $uri =404'));
    });

    test('the manifest claims paths, never the bare host', () {
      final manifest =
          File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
      expect(manifest, contains('android:autoVerify="true"'));

      // A <data> element carrying a host with no path claims EVERY url on the
      // domain — including /app/* operator surfaces and anything added later.
      final hostOnly = RegExp(
          r'<data\s+android:scheme="https"\s+android:host="orchestrateops\.com"\s*/>');
      expect(hostOnly.hasMatch(manifest), isFalse,
          reason: 'a bare host claim would silently widen as routes are added');

      final claimed = RegExp(r'android:host="orchestrateops\.com"\s+android:path="([^"]+)"')
          .allMatches(manifest)
          .map((m) => m.group(1)!)
          .toSet();
      expect(claimed, isNotEmpty);
      expect(claimed.any((p) => p.startsWith('/app/')), isFalse,
          reason: 'operator surfaces are not public continuation targets');
    });

    test('what the web offers and what the app claims are the same set', () {
      // The two drifting apart is the whole failure mode: the web rail would
      // offer to continue in the app on a path the app does not claim.
      final config =
          File('lib/features/public/widgets/public_app_acquisition.dart')
              .readAsStringSync();
      final start = config.indexOf('orchestratePublicAppAcquisitionConfig');
      final open = config.indexOf('eligiblePaths: {', start);
      final body = config.substring(open, config.indexOf('},', open));
      final eligible = RegExp("'([^']+)'")
          .allMatches(body)
          .map((m) => m.group(1)!)
          .toSet();

      final manifest =
          File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
      final claimed = RegExp(r'android:host="orchestrateops\.com"\s+android:path="([^"]+)"')
          .allMatches(manifest)
          .map((m) => m.group(1)!)
          .toSet();

      expect(claimed, equals(eligible),
          reason: 'acquisition eligibility and native association disagree:\n'
              'web only: ${eligible.difference(claimed)}\n'
              'app only: ${claimed.difference(eligible)}');
    });
  });
}
