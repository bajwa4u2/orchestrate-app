import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String read(String path) => File(path).readAsStringSync();

  test('public visual system has a canonical shell and visual register', () {
    final shell = read('lib/app/shell/public_shell.dart');
    final register = read('docs/ORCHESTRATE_PUBLIC_VISUAL_SURFACE_REGISTER.md');
    expect(shell, contains('class PublicShell'));
    expect(shell, contains('_CommercialClosingBand'));
    // Founder, 1 Oct 2026: startup programmes live on the company site only.
    expect(shell, isNot(contains('_CommercializationSupportBand')));
    expect(shell, contains('_PublicFooter'));
    expect(shell, contains('backgroundColor: AppTheme.publicCanvas'));
    expect(shell, contains("currentPath != '/intake'"));
    expect(register, contains('listed route is mounted through `PublicShell`'));
  });

  test('estate owns the ending and no legacy Home close remains', () {
    final shell = read('lib/app/shell/public_shell.dart');
    final home = read('lib/features/public/screens/public_home_screen.dart');
    expect(shell, contains('const _CommercialClosingBand()'));
    expect(home, isNot(contains('_ClosingSection')));
    expect(home,
        isNot(contains('Ready to activate revenue automation infrastructure')));
  });

  test('no product shows startup programme marks', () {
    final shell = read('lib/app/shell/public_shell.dart');
    final visuals =
        read('lib/features/public/widgets/execution_visual_chapters.dart');
    for (final source in [shell, visuals]) {
      expect(source, isNot(contains('OfficialSupportMarks')));
      expect(source, isNot(contains('Microsoft for Startups')));
      expect(source, isNot(contains('Google for Startups')));
      expect(source, isNot(contains('AWS Activate')));
    }
    expect(Directory('assets/branding/support').existsSync(), isFalse);
  });

  test('public identity uses the canonical transparent lockup', () {
    final shell = read('lib/app/shell/public_shell.dart');
    final brand = read('lib/core/brand/brand_assets.dart');
    expect(shell, contains('BrandAssets.operatorLockup'));
    // DD-26: the header is paper, so the lockup is drawn for a light surface.
    expect(shell, contains('darkSurface: false'));
    expect(shell, isNot(contains('orchestrate_logo_dark.png')));
    expect(brand, contains('orchestrate_symbol_dark.png'));
  });

  test('footer keeps attribution but does not mount the ecosystem nav row', () {
    final shell = read('lib/app/shell/public_shell.dart');
    final footer = shell.substring(
      shell.indexOf('class _PublicFooter extends'),
      shell.indexOf('class _FooterGroup extends'),
    );
    // DD-26 F1: the bottom row sits in a const list beside the supporters.
    expect(footer, contains('_PublicFooterBottomRow()'));
    expect(shell, contains("slug: 'aura'"));
    expect(shell, contains("slug: 'colophon'"));
    expect(shell, contains("slug: 'founder'"));

    // The portfolio names the CURRENT products. This footer shipped
    // "Bajwa Writes" as a live product label until 2026-09-13, and it survived
    // the estate-wide rename because Orchestrate's home renders on canvas --
    // the string never appears in served HTML, so an audit that fetches the
    // page cannot see it. Only a source assertion can.
    expect(shell, contains("label: 'Colophon'"));
    expect(shell, isNot(contains('Bajwa Write')),
        reason: 'the footer names a retired product name as current');
    expect(shell, isNot(contains("slug: 'company'")));
    expect(shell, isNot(contains("slug: 'orchestrate'")));
    expect(shell, isNot(contains('Why Orchestrate exists')));
    expect(shell, isNot(contains('How Orchestrate operates')));
    // Founder 2026-10-01: two lines of links, no columns, so nothing leaves
    // empty space under an uneven column; the lines wrap on a phone.
    expect(shell, contains('final site = Wrap('));
    expect(shell, contains('final policies = Wrap('));
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
    final ops = read('lib/features/auth/screens/ops_login_screen.dart');
    final journey = read('docs/ORCHESTRATE_VISIBLE_JOURNEY_REGISTER.md');
    expect(authShell, contains('class AuthShell'));
    // DD-26: the dark four-step band named a different path; retired.
    expect(authShell, isNot(contains('_SetupJourneyHeader')));
    expect(router, contains("path: '/auth/login'"));
    expect(router, contains("path: '/auth/register'"));
    expect(router, contains("path: '/app/setup'"));
    expect(router, contains("path: '/app/subscribe'"));
    expect(setup, contains('setupFlow: true'));
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

  test('public content reads in direction B, without the retired chapters',
      () {
    // DD-26: every legal and explainer page shares one paper template. The
    // dark visual chapters belonged to the retired look; the parameter stays
    // so callers compile, but nothing draws it.
    final content =
        read('lib/features/public/screens/public_content_screen.dart');
    expect(content, contains('final Widget? visualChapter'));
    expect(content, isNot(contains('visualChapter!')));
    expect(content, contains('ObHeadline(title'));
    expect(content, isNot(contains('publicDeepField')));
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
    // DD-26: the footer names only pages in the new design.
    expect(shell, contains("link('One customer, start to paid'"));
    expect(shell, contains("link('Check your domain'"));
    expect(shell, contains("link('All policies'"));
    expect(shell, contains("focus=dns-readiness"));
    expect(shell, isNot(contains("label: 'Product'")));
    expect(shell, isNot(contains("label: 'Signals and sourcing'")));
    expect(shell, isNot(contains("label: 'Why Orchestrate exists'")));
    expect(shell, isNot(contains("label: 'How Orchestrate operates'")));
    expect(contract, contains('Retired from footer'));
  });

  test('named footer destinations are addressable and logo resets home', () {
    final shell = read('lib/app/shell/public_shell.dart');
    final diagnostics =
        read('lib/features/public/screens/public_diagnostics_screen.dart');
    expect(shell, contains('jumpTo(0)'));
    // DD-26: every policy stays one tap away through the policies index.
    expect(shell, contains("'/legal'"));
    // Account deletion is reached through the policies index.
    expect(shell, contains("link('All policies', '/legal')"));
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
    // DD-26 (board S05): sign-up leads with what happens next.
    expect(auth, contains('Six minutes to set up. Then Orchestrate starts looking.'));
    expect(auth, contains('Welcome back.'));
  });
}
