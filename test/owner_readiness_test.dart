import 'package:flutter_test/flutter_test.dart';
import 'package:orchestrate_app/core/readiness/owner_readiness.dart';

void main() {
  Map<String, dynamic> chain(Set<String> ready) => {
        'chain': [
          for (final k in [
            'setup', 'subscription', 'representation', 'business_identity',
            'sending_domain', 'trust', 'sending_transport', 'reply_monitoring',
          ])
            {'key': k, 'state': ready.contains(k) ? 'ready' : 'pending'},
        ],
      };

  test('a new workspace has all four owner steps open, in order', () {
    final steps = ownerStepsFrom(chain({'setup'}));
    expect(steps.map((s) => s.key), ['act', 'email', 'domain', 'plan']);
    expect(steps.every((s) => !s.done), isTrue);
  });

  test('each step reads its own layer of the server chain', () {
    final steps = ownerStepsFrom(chain({'representation', 'trust'}), authority: 'ESTABLISHED');
    final done = {for (final s in steps) s.key: s.done};
    expect(done, {'plan': false, 'act': true, 'email': false, 'domain': true});
    // Permission alone is not enough: the business must recognise who decides.
    final pending = ownerStepsFrom(chain({'representation'}), authority: 'UNDER_REVIEW');
    expect(pending.firstWhere((s) => s.key == 'act').done, isFalse);
  });

  test('who acts for it says what comes first until plan and email are set', () {
    // Founder walk, 2 Oct 2026: "Finish this step" opened a locked step.
    final locked = ownerStepsFrom(chain({'setup'})).firstWhere((s) => s.key == 'act');
    expect(locked.cta, 'See what comes first');
    expect(locked.route, '/client/setup');
    expect(locked.waiting, isTrue, reason: 'not a yes the owner can give yet');
    final open = ownerStepsFrom(chain({'subscription', 'sending_transport'}))
        .firstWhere((s) => s.key == 'act');
    expect(open.cta, 'Finish this step');
    expect(open.route, '/client/setup?step=permission');
    expect(open.waiting, isFalse);
  });

  test('a connected mailbox that cannot send keeps the email card open', () {
    final e = chain({'sending_transport'});
    e['blockers'] = [{'code': 'MAILBOX_CREDENTIAL_MISSING'}];
    final email = ownerStepsFrom(e).firstWhere((s) => s.key == 'email');
    expect(email.done, isFalse);
    expect(email.cta, 'Reconnect email');
  });

  test('an unanswered chain shows nothing rather than guessing', () {
    expect(ownerStepsFrom(null), isEmpty);
    expect(ownerStepsFrom({'blockers': []}), isEmpty);
  });

  test('the server names the place; no route means Setup', () {
    expect(setupRouteFor('/client/setup?step=email'), '/client/setup?step=email');
    expect(setupRouteFor('/client/money'), '/client/money');
    expect(setupRouteFor(null), '/client/setup');
  });
}
