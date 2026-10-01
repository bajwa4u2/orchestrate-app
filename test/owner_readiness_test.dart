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
    expect(steps.map((s) => s.key), ['plan', 'act', 'email', 'domain']);
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

  test('older resolution pages map to the setup step that does the job', () {
    expect(setupRouteFor('/client/infrastructure?focus=domain'), '/client/setup?step=email');
    expect(setupRouteFor('/client/billing'), '/client/setup?step=plan');
    expect(setupRouteFor('/client/representation'), '/client/setup?step=business');
    expect(setupRouteFor('/client/money'), '/client/money');
    expect(setupRouteFor(null), '/client/setup');
  });
}
