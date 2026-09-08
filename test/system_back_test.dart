import 'package:flutter_test/flutter_test.dart';
import 'package:orchestrate_app/app/routing/app_router.dart';
import 'package:orchestrate_app/core/navigation/workspace_map.dart';

/// System Back on Android, which used to close the app from any page.
///
/// Public navigation is `go`, so nothing sat on the Flutter stack to pop and
/// Android closed the task. Proven on a physical Pixel: home → Pricing → Back
/// left Orchestrate. Proven twice, because the first repair — a
/// BackButtonDispatcher — never ran: Android asks whether the app handles Back
/// before delivering it, and only PopScope answers yes.
///
/// These assertions fix what Back means, and that it agrees with the return
/// already drawn on screen.
void main() {
  String? up(String path) => WorkspaceBack.parentOf(path);

  group('Back leaves the app only where leaving is what it means', () {
    test('the public front door is the last surface', () {
      expect(up('/'), isNull);
      expect(up(''), isNull);
    });

    test('Today is where the workspace begins, so Back leaves from it', () {
      expect(up('/client/today'), isNull);
    });
  });

  group('Back goes up, not out', () {
    test('a marketing page returns to the front door', () {
      expect(up('/pricing'), '/');
      expect(up('/product'), '/');
      expect(up('/how-it-works'), '/');
    });

    test('signing in returns to the site it was reached from', () {
      expect(up('/auth/login'), '/');
      expect(up('/auth/register'), '/');
    });

    test('another landing returns to Today rather than leaving', () {
      expect(up('/client/market'), '/client/today');
      expect(up('/client/relationships'), '/client/today');
      expect(up('/client/business'), '/client/today');
    });
  });

  group('System Back agrees with the return drawn on screen', () {
    // The shell renders its own return from semanticParentOf. If these two
    // disagreed, the same gesture would mean different things depending on
    // whether a person used the screen or the phone.
    const surfaces = [
      '/client/settings',
      '/client/support',
      '/client/trust',
      '/client/records',
      '/client/subscribe',
      '/client/business-identity',
      '/account/plan',
      '/account/security',
    ];

    test('every non-landing workspace surface uses the visible parent', () {
      for (final path in surfaces) {
        if (isAreaLanding(path)) continue;
        final visible = semanticParentOf(path);
        if (visible == null) continue;
        expect(
          up(path),
          visible,
          reason: 'system Back on $path disagreed with the on-screen return',
        );
      }
    });

    test('a surface off the map still lands somewhere real', () {
      expect(up('/client/made/up/path'), isNotNull);
      expect(up('/client/made/up/path')!.startsWith('/client'), isTrue);
    });
  });
}
