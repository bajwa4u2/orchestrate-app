import 'dart:io';

/// THE BACKEND, WHEN IT IS CHECKED OUT BESIDE THIS REPOSITORY.
///
/// Several contracts in this suite genuinely span both repositories — that a
/// refusal the client renders is the one the server sends, that the store
/// rails follow one commercial policy, that a person's name has a route to
/// change it. Reading the server's source is the honest way to pin them, and
/// they are worth pinning.
///
/// But they were written as `File('../orchestrate_backend/...')`, which is
/// true only where somebody has both repositories side by side. CI clones one
/// repository. So eight tests passed on a developer machine and failed on the
/// Codemagic runner — and because `flutter test` gates the iOS build, they
/// failed it at step six, forty seconds in, with the whole thing looking like
/// a toolchain problem.
///
/// Present, they run. Absent, they skip and say why. What must never happen
/// again is a client-repository test that silently requires a sibling
/// checkout.
const _root = '../orchestrate_backend';

/// Whether the sibling checkout exists at all.
bool get backendIsCheckedOut => Directory(_root).existsSync();

/// The reason to give `skip:`, or null when the tests can really run.
///
/// Passed straight to `skip:` so a skipped test says what is missing rather
/// than disappearing.
String? get backendSkipReason => backendIsCheckedOut
    ? null
    : 'needs the backend checked out beside this repository '
        '($_root); only one repository is cloned on CI';

/// Read a file from the sibling backend.
///
/// Only call this from a test carrying `skip: backendSkipReason` — it throws
/// where the checkout is absent, deliberately, so a missing guard is loud
/// rather than a test that quietly asserts nothing.
String backendSource(String path) => File('$_root/$path').readAsStringSync();
