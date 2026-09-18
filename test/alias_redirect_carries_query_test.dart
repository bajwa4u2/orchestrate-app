// A LINK IN AN EMAIL IS THE ONLY WAY THIS PATH IS EVER REACHED.
//
// The backend mails confirmation links to /client/verify-email?token=…. The
// router aliased that to /auth/verify-email with a bare string, which dropped
// the query. The destination reads ?token to call verifyEmail — so every
// emailed link landed on a screen with nothing to verify, and the person was
// shown the same "Confirm your email" prompt that had sent them there.
//
// Found by clicking a real confirmation link from a real mailbox on
// 2026-09-17. It could not have been found from inside the app: the token only
// exists in mail, so nothing a person clicks in the product reaches this code.
//
// Eleven aliases had the same shape. These hold all of them, because the next
// one added will be written by copying a neighbour.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late final String source =
      File('lib/app/routing/app_router.dart').readAsStringSync();

  /// Every alias that lands on an auth screen. The destinations read `token`
  /// (verification, reset) or `returnTo` (login, join) off the query, so an
  /// alias that discards it discards the entire point of the link.
  const aliases = <String, String>{
    '/login': '/auth/login',
    '/join': '/auth/join',
    '/signup': '/auth/join',
    '/forgot-password': '/auth/reset-password',
    '/reset-password': '/auth/reset-password',
    '/verify-email': '/auth/verify-email',
    '/client/login': '/auth/login',
    '/client/join': '/auth/join',
    '/client/signup': '/auth/join',
    '/client/verify-email': '/auth/verify-email',
    '/client/reset-password': '/auth/reset-password',
  };

  group('an auth alias carries the query it was given', () {
    aliases.forEach((from, to) {
      test('$from -> $to keeps the query', () {
        final at = source.indexOf("path: '$from'");
        expect(at, greaterThan(-1), reason: '$from must still be routed');

        final next = source.indexOf('GoRoute(', at);
        final declaration =
            source.substring(at, next == -1 ? source.length : next);

        expect(
          declaration.contains("_alias(state, '$to')"),
          isTrue,
          reason: '$from must redirect through _alias so ?token and ?returnTo '
              'survive. A bare "=> \'$to\'" silently drops them, which is what '
              'killed every emailed verification link.',
        );
      });
    });
  });

  group('the helper itself', () {
    test('it is present and appends the query rather than rebuilding it', () {
      expect(source.contains('String _alias(GoRouterState state'), isTrue);
      // Appending the raw query preserves the exact encoding the provider sent.
      // Re-encoding through Uri.queryParameters would round-trip a JWT's
      // padding and separators, and a token that changes is a token that fails.
      expect(source.contains("return '\$destination?\$query';"), isTrue,
          reason: 'the raw query is passed through unaltered');
      expect(source.contains('if (query.isEmpty) return destination;'), isTrue,
          reason: 'no trailing ? when there was no query');
    });
  });

  group('the destination still consumes what the alias now delivers', () {
    test('the verification screen reads token off the query', () {
      final login = File('lib/features/auth/screens/client_login_screen.dart')
          .readAsStringSync();
      expect(login.contains("uri.queryParameters['token']"), isTrue,
          reason: 'if this moves, the aliases above are carrying nothing');
      expect(login.contains('AuthRepository().verifyEmail(token)'), isTrue);
    });
  });
}
