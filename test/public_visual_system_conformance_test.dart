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

  /// THIS RULE WAS REVERSED, DELIBERATELY.
  ///
  /// It used to require all three support marks to be image assets — "governed
  /// assets, not text pills" — and it named the two SVG files. That was the
  /// right instinct aimed at the wrong thing: it defended the presence of two
  /// files that were never issued to anybody here. The Google file was the
  /// plain "G" from the Simple Icons set (its own `<title>` says `Google`) and
  /// the AWS file was an architecture *diagram* icon, `Arch_AWS-Activate_48`,
  /// on the magenta category tile that icon set uses inside diagrams.
  ///
  /// Settled in the Bajwa Writes estate on 2026-09-07 against both companies'
  /// own published guidance, and applied here on founder instruction for
  /// parity across the estates. A mark may stand for a programme only if it is
  /// that programme's authorised mark; where the mark is granted rather than
  /// published, the programme's name is the authorised representation.
  ///
  /// So the rule now runs the other way: the Microsoft badge is real and must
  /// stay an image, and the other two must be words and must not reach for the
  /// retired files.
  test('a mark is used only where a mark was actually issued', () {
    final shell = read('lib/app/shell/public_shell.dart');
    final visuals =
        read('lib/features/public/widgets/execution_visual_chapters.dart');
    expect(shell, contains('OfficialSupportMarks'));

    // Genuine, founder-approved, and provided by Microsoft.
    expect(visuals, contains('microsoft-for-startups-badge.png'));

    // Never issued. Neither file may come back, and neither may any other
    // stand-in reached for under the same name.
    expect(visuals, isNot(contains('google-for-startups.svg')));
    expect(visuals, isNot(contains('aws-activate.svg')));
    expect(File('assets/branding/support/google-for-startups.svg').existsSync(),
        isFalse);
    expect(
        File('assets/branding/support/aws-activate.svg').existsSync(), isFalse);

    // Named in words, and each linked to the programme so a reader can check
    // the claim at its source.
    expect(visuals, contains("_SupportWord('Google for Startups'"));
    expect(visuals, contains("_SupportWord('AWS Activate'"));
    expect(visuals, contains('https://startup.google.com/'));
    expect(visuals, contains('https://aws.amazon.com/activate/'));
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
    expect(shell, isNot(contains('Why Orchestrate exists')));
    expect(shell, isNot(contains('How Orchestrate operates')));
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
    expect(shell, contains('maxWidth: shellWidth'));
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
    expect(router, contains("path: '/auth/register'"));
    expect(router, contains("path: '/app/setup'"));
    expect(router, contains("path: '/app/subscribe'"));
    expect(setup, contains('setupFlow: true'));
    expect(subscribe, contains('setupFlow: true'));
    expect(ops, contains('AuthShell'));
    expect(journey, contains('Orchestrate visible journey register'));
  });

  test('first workspace entry inherits the Orchestrate receiving frame', () {
    final shell = read('lib/app/shell/client_shell.dart');
    final journey = read('docs/ORCHESTRATE_VISIBLE_JOURNEY_REGISTER.md');
    // The boundary is still converged: identity, sidebar and page chrome are
    // owned here.
    //
    // What changed is where the tokens come from. The shell used to render
    // with the marketing site's ThemeData, which is why the authenticated
    // product drifted to white cards on grey while the public surfaces gained
    // depth — and why it carried a 54px headline and 16px of button padding
    // into an environment somebody works in all day. It now has a theme of
    // its own.
    expect(shell, contains('data: Ws.data'),
        reason: 'the workspace renders with its own theme, not the public one');
    expect(shell, isNot(contains('data: AppTheme.lightTheme')),
        reason: 'inheriting the marketing ThemeData is the drift this '
            'reconstruction exists to end');
    // THE PRODUCT MARK IS NO LONGER PART OF THIS FRAME.
    //
    // This asserted the authenticated shell carried BrandAssets.symbol. The
    // founder's correction is that a client's workspace belongs to the client:
    // the rail opened with Orchestrate's mark and wordmark and put the
    // business underneath, which is the infrastructure sitting above the
    // company whose workspace it is.
    //
    // The convergence this test protects is the THEME and the chrome, not the
    // branding — and both still hold above. Orchestrate still names itself on
    // the public site, in auth before a business context exists, and in the
    // version row.
    expect(shell, isNot(contains('BrandAssets.symbol')),
        reason: 'a client workspace shell must lead with the client, not the '
            'product');

    // THE CONTENT PANE STAYS LIGHT. This is the property the original
    // assertion was really protecting: an earlier shell inherited the dark
    // receiving canvas and rendered dark content on it, which left the pane
    // unreadable. The rail is now a deep field on purpose — it is what carries
    // identity across from the public product — so the guard has to say which
    // surface may be deep rather than banning the field outright.
    expect(shell, contains('color: Ws.canvas'),
        reason: 'the work area sits on the light workspace ground');
    expect(shell, isNot(contains('backgroundColor: Ws.field')),
        reason: 'the scaffold behind the content must never be the deep field');
    expect(shell, isNot(contains('ColoredBox(\n        color: Ws.field')),
        reason: 'the content pane must never be the deep field');
    expect(journey, contains('converged receiving boundary'));
    expect(
        journey, isNot(contains('EXEMPT_WITH_REASON: operational workspace')));
  });

  test(
      'direct setup intent begins with registration for unauthenticated visitors',
      () {
    final router = read('lib/app/routing/app_router.dart');
    expect(router, contains("if (isSetup || isSubscribe)"));
    expect(router, contains("_clientRoute('/auth/register'"));
  });

  test('public content uses the shared visual chapter hook', () {
    final content =
        read('lib/features/public/screens/public_content_screen.dart');
    expect(content, contains('final Widget? visualChapter'));
    expect(content, contains('visualChapter!'));
    expect(content, contains('color: AppTheme.publicDeepField'));
    expect(content, contains('color: AppTheme.publicOnDarkMuted'));
  });

  test('Home restores the live lifecycle flagship before the hero', () {
    final home = read('lib/features/public/screens/public_home_screen.dart');
    final flagship =
        read('lib/features/public/widgets/public_overview_widget.dart');
    final flagshipIndex = home.indexOf('const PublicOverviewWidget()');
    final heroIndex = home.indexOf('CommercialHero(');
    expect(flagshipIndex, greaterThan(-1));
    expect(heroIndex, greaterThan(flagshipIndex));
    expect(flagship, contains("fetchLifecycle()"));
    expect(flagship, contains("_payload?['cards']"));
    expect(flagship, contains("node.kind == 'ASSET'"));
    expect(flagship, contains('MediaQuery.disableAnimationsOf(context)'));
    expect(flagship, contains('The public authority could not be reached'));
    expect(flagship, contains('class _NetworkPainter'));
    expect(flagship, contains('OPERATING NOW'));
    expect(flagship, contains('SingleTickerProviderStateMixin'));
    expect(flagship, isNot(contains("'283'")));
    expect(flagship, isNot(contains("'220'")));
    expect(flagship, isNot(contains("'78'")));
  });

  test('public footer follows the current destination contract', () {
    final shell = read('lib/app/shell/public_shell.dart');
    final contract = read('docs/ORCHESTRATE_CLICKABLE_JOURNEY_MATRIX.md');
    expect(shell, contains("label: 'Product'"));
    expect(shell, contains("label: 'Signals and sourcing'"));
    expect(shell, contains("label: 'DNS readiness check'"));
    expect(shell, contains("focus=dns-readiness"));
    expect(shell, isNot(contains("label: 'Why Orchestrate exists'")));
    expect(shell, isNot(contains("label: 'How Orchestrate operates'")));
    expect(contract, contains('Retired from footer'));
  });

  test('named footer destinations are addressable and logo resets home', () {
    final shell = read('lib/app/shell/public_shell.dart');
    final diagnostics =
        read('lib/features/public/screens/public_diagnostics_screen.dart');
    expect(shell, contains('jumpTo(0)'));
    expect(shell, contains("'/legal/service-agreement'"));
    expect(shell, contains("'/legal/refunds'"));
    expect(shell, isNot(contains("label: 'Acceptable use'")));
    expect(diagnostics, contains("focus == 'dns-readiness'"));
    expect(diagnostics, contains('Scrollable.ensureVisible'));
  });

  test('footer destinations preserve browser return intent', () {
    final shell = read('lib/app/shell/public_shell.dart');
    final footer = shell.substring(
      shell.indexOf('class _PublicFooter extends'),
      shell.indexOf('class _FooterGroup extends'),
    );
    expect(footer, contains('context.push'));
    expect(footer, isNot(contains('context.go')));
  });

  test('imperative web destinations project into browser URL history', () {
    final router = read('lib/app/routing/app_router.dart');
    expect(router, contains('GoRouter.optionURLReflectsImperativeAPIs = true'));
  });

  test('footer rows and acquisition intent remain directly actionable', () {
    final shell = read('lib/app/shell/public_shell.dart');
    final auth = read('lib/features/auth/screens/client_login_screen.dart');
    expect(shell, contains('width: double.infinity'));
    expect(auth, contains('CREATE ACCESS  →  SETUP  →  READINESS'));
    expect(auth, contains('ACCOUNT ACCESS'));
  });
}
