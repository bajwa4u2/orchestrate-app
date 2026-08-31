import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String read(String path) => File(path).readAsStringSync();

  test('public visual system has a canonical shell and visual register', () {
    final shell = read('lib/app/shell/public_shell.dart');
    final register = read('docs/ORCHESTRATE_PUBLIC_VISUAL_SURFACE_REGISTER.md');
    expect(shell, contains('class PublicShell'));
    expect(shell, contains('_CommercialClosingBand'));
    expect(shell, contains('_CommercializationSupportBand'));
    expect(shell, contains('_PublicFooter'));
    expect(shell, contains('backgroundColor: AppTheme.publicCanvas'));
    expect(shell, contains("currentPath != '/intake'"));
    expect(register, contains('listed route is mounted through `PublicShell`'));
  });

  test('estate owns the ending and no legacy Home close remains', () {
    final shell = read('lib/app/shell/public_shell.dart');
    final home = read('lib/features/public/screens/public_home_screen.dart');
    expect(shell, contains('const _CommercialClosingBand()'));
    expect(shell, contains('const _CommercializationSupportBand()'));
    expect(home, isNot(contains('_ClosingSection')));
    expect(home,
        isNot(contains('Ready to activate revenue automation infrastructure')));
  });

  test('support marks remain governed assets, not text pills', () {
    final shell = read('lib/app/shell/public_shell.dart');
    final visuals =
        read('lib/features/public/widgets/execution_visual_chapters.dart');
    expect(shell, contains('OfficialSupportMarks'));
    expect(visuals, contains('microsoft-for-startups-badge.png'));
    expect(visuals, contains('google-for-startups.svg'));
    expect(visuals, contains('aws-activate.svg'));
  });

  test('public identity uses the canonical transparent lockup', () {
    final shell = read('lib/app/shell/public_shell.dart');
    final brand = read('lib/core/brand/brand_assets.dart');
    expect(shell, contains('BrandAssets.operatorLockup'));
    expect(shell, contains('darkSurface: true'));
    expect(shell, isNot(contains('orchestrate_logo_dark.png')));
    expect(brand, contains('orchestrate_symbol_dark.png'));
  });

  test('footer keeps attribution but does not mount the ecosystem nav row', () {
    final shell = read('lib/app/shell/public_shell.dart');
    final footer = shell.substring(
      shell.indexOf('class _PublicFooter extends'),
      shell.indexOf('class _FooterGroup extends'),
    );
    expect(footer, contains('const _PublicFooterBottomRow()'));
    expect(shell, contains("slug: 'aura'"));
    expect(shell, contains("slug: 'bajwa-writes'"));
    expect(shell, contains("slug: 'founder'"));
    expect(shell, isNot(contains("slug: 'company'")));
    expect(shell, isNot(contains("slug: 'orchestrate'")));
    expect(shell, contains('final columnWidth'));
    expect(shell, contains('spacing: 20'));
  });

  test('public shell has one explicit scroll owner', () {
    final shell = read('lib/app/shell/public_shell.dart');
    expect(
        shell, contains('class _PublicShellState extends State<PublicShell>'));
    expect(shell, contains('final ScrollController _publicScrollController'));
    expect(shell, contains('Scrollbar('));
    expect(shell, contains('controller: _publicScrollController'));
    expect(shell, contains('interactive: true'));
    expect(shell, contains('SingleChildScrollView('));
    expect(shell, isNot(contains('Listener(')));
  });

  test('visible acquisition journey has canonical auth and setup owners', () {
    final authShell = read('lib/app/shell/auth_shell.dart');
    final router = read('lib/app/routing/app_router.dart');
    final setup = read('lib/features/client/screens/client_setup_screen.dart');
    final subscribe =
        read('lib/features/client/screens/client_subscribe_screen.dart');
    final ops = read('lib/features/auth/screens/ops_login_screen.dart');
    final journey = read('docs/ORCHESTRATE_VISIBLE_JOURNEY_REGISTER.md');
    expect(authShell, contains('class AuthShell'));
    expect(authShell, contains('_SetupJourneyHeader'));
    expect(router, contains("path: '/auth/login'"));
    expect(router, contains("path: '/app/setup'"));
    expect(router, contains("path: '/app/subscribe'"));
    expect(setup, contains('setupFlow: true'));
    expect(subscribe, contains('setupFlow: true'));
    expect(ops, contains('AuthShell'));
    expect(journey, contains('Orchestrate visible journey register'));
  });

  test('public content uses the shared visual chapter hook', () {
    final content =
        read('lib/features/public/screens/public_content_screen.dart');
    expect(content, contains('final Widget? visualChapter'));
    expect(content, contains('visualChapter!'));
  });
}
