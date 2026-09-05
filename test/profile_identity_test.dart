import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A SAVED PROFILE HAS TO SURFACE, AND YOU HAVE TO BE ABLE TO EDIT YOUR NAME.
///
/// Reported from the product: the name on the account screen comes from
/// onboarding, and a saved profile does not appear. Both were true, for two
/// different reasons.
///
/// There was no way to change your own name anywhere. `User.fullName` was
/// whatever was typed at registration, shown back on the account screen
/// forever, with an "Edit profile" form beside it that edits the BUSINESS. No
/// endpoint in the backend updated it.
///
/// And there were two business names. The form renames the `Client`; the rail,
/// the account menu and the name shown after every sign-in read the
/// `Organization`, which nothing touched and no screen could edit. So a
/// business renamed itself, watched it take on one page, and went on being
/// called the old name everywhere else.
void main() {
  String app(String p) => File(p).readAsStringSync();
  String backend(String p) => File('../orchestrate_backend/$p').readAsStringSync();

  test('a person can change their own name', () {
    final service = backend('src/auth/auth.service.ts');
    expect(service.contains('async updateMe('), isTrue);
    expect(service.contains('data: { fullName },'), isTrue);
    // Refused rather than stored blank, and answered in the person's words.
    expect(service.contains('Enter the name you want to be known by.'), isTrue);
    expect(backend('src/auth/auth.controller.ts').contains('updateMe('), isTrue);
  });

  test('the form offers it, and it is about the person', () {
    final screen =
        app('lib/features/client/screens/client_account_screen.dart');
    expect(screen.contains("label: 'Your name'"), isTrue);
    expect(screen.contains('updateOwnName('), isTrue);
    // Its own call, not a field on the client profile: a workspace can have
    // several people, and one renaming themselves must not rename the company.
    final repo =
        app('lib/data/repositories/client/client_account_repository.dart');
    expect(repo.contains("'/auth/me'"), isTrue);
    expect(repo.contains('updateOwnName'), isTrue);
  });

  test('one business, one name', () {
    final clients = backend('src/clients/clients.service.ts');
    final save = clients.substring(clients.indexOf('async saveProfile('));
    expect(save.contains('organization.update('), isTrue);
    // Only where there is nothing to disambiguate. An organisation holding
    // several clients must not be renamed by one of them.
    expect(save.contains('siblings === 1'), isTrue);
    expect(
      save.indexOf('client.count(') < save.indexOf('organization.update('),
      isTrue,
      reason: 'the count decides whether the organisation may be renamed',
    );
  });

  test('the session is refreshed from the server after a save', () {
    final screen =
        app('lib/features/client/screens/client_account_screen.dart');
    expect(screen.contains('applyAuthResponse(await widget.repository.fetchMe())'),
        isTrue,
        reason: 'the rail and the account menu read the session, not the screen');
  });

  test('a refusal is shown in the words the server used', () {
    final screen =
        app('lib/features/client/screens/client_account_screen.dart');
    expect(screen.contains('String? _refusalText('), isTrue);
    // 4xx only. A 5xx or a dropped connection has nothing worth quoting.
    expect(screen.contains('statusCode < 400 || error.statusCode >= 500'), isTrue);
  });
}
