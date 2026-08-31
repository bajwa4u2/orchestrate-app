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
    expect(home, isNot(contains('Ready to activate revenue automation infrastructure')));
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

  test('public content uses the shared visual chapter hook', () {
    final content =
        read('lib/features/public/screens/public_content_screen.dart');
    expect(content, contains('final Widget? visualChapter'));
    expect(content, contains('visualChapter!'));
  });
}
