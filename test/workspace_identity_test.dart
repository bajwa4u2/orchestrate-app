import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The business owns the workspace. The person acts inside it.
///
/// The shell answered "which human am I?" and never "which business am I
/// operating?". On a phone the app bar said the surface name — the fourth
/// place on screen saying it, after the heading, the breadcrumb and the
/// selected destination — while the only identity visible was the account
/// avatar, which is the person.
///
/// These assertions fix the hierarchy: business identity leads the workspace
/// shell, the person leads only on the account estate, and neither the mark nor
/// the name is stored here — the shell reads Branding and Business identity and
/// writes neither.
void main() {
  String read(String path) => File(path).readAsStringSync();

  final shell = read('lib/app/shell/client_shell.dart');
  final mark = read('lib/features/client/widgets/workspace_mark.dart');

  group('the workspace shell leads with the business', () {
    test('the phone app bar carries workspace identity, not a surface name',
        () {
      expect(shell.contains('WorkspaceIdentity(showPerson:'), isTrue);
      expect(
        shell.contains('title: Text(_currentLabel())'),
        isFalse,
        reason: 'the app bar was the only place that could name the business',
      );
    });

    test('the rail carries the mark, and keeps it when collapsed', () {
      expect(shell.contains('WorkspaceMark(onDark: true)'), isTrue);
      // Twice: once beside the name, once alone when collapsed.
      expect(
        'WorkspaceMark(onDark: true)'.allMatches(shell).length,
        greaterThanOrEqualTo(2),
        reason: 'a collapsed rail must still say whose workspace it is',
      );
    });
  });

  group('the person leads only where the person is the subject', () {
    test('account surfaces show the person', () {
      expect(shell.contains('showPerson: _inAccountLayer'), isTrue);
      expect(mark.contains('final bool showPerson'), isTrue);
    });

    test('a business with no logo never falls back to the operator', () {
      // The fallback initial is drawn from the workspace name, never from the
      // signed-in person — presenting a person as though they were the company
      // is the exact confusion this hierarchy exists to prevent.
      expect(mark.contains('Initial(text: business'), isTrue);
    });
  });

  group('the shell consumes identity and owns none of it', () {
    test('it reads branding rather than storing a logo', () {
      expect(mark.contains('ClientBrandingRepository'), isTrue);
      expect(
        mark.contains('logo_primary'),
        isTrue,
        reason: 'the canonical branding asset, not a shell-specific field',
      );
    });

    test('it reads the business name from the session, not a local field', () {
      expect(mark.contains('session.workspaceName'), isTrue);
    });

    test('logo presence is re-asked when the business context changes', () {
      // Hardcoding one business, or caching without a key, would show the
      // previous company's mark after a context switch.
      expect(mark.contains('resolvedFor'), isTrue);
      expect(mark.contains('resolvedFor == workspace'), isTrue);
    });
  });
}
