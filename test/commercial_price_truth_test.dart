import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:orchestrate_app/core/commercial/commercial_model.dart';

/// WHAT A VISITOR IS TOLD ORCHESTRATE COSTS.
///
/// The client's half of the contract. The server publishes one price; these
/// assertions are about the ways a client can take a correct answer and render
/// a wrong one — by ranking two cadences, by rounding a price, or by keeping a
/// number of its own.
void main() {
  /// Exactly the shape `/public/pricing` returns.
  Map<String, dynamic> payload() => {
        'model': 'ORGANIZATION_PLATFORM_SUBSCRIPTION',
        'says': 'Orchestrate is priced primarily at the level of your '
            'organisation.',
        'dimensions': [
          {'dimension': 'PLATFORM_SUBSCRIPTION', 'means': 'A subscription.'},
        ],
        'pricing': {
          'state': 'PUBLISHED',
          'says': 'One subscription for your organisation.',
          'free': {
            'amountUsdCents': 0,
            'says': 'Creating a workspace costs nothing.',
          },
          // Annual first, deliberately: the server does not promise an order,
          // so the client must not inherit one.
          'plans': [
            {
              'period': 'ANNUAL',
              'entitlement': 'ORCHESTRATE_PLATFORM',
              'amountUsdCents': 29999,
              'says': 'Billed once a year.',
            },
            {
              'period': 'MONTHLY',
              'entitlement': 'ORCHESTRATE_PLATFORM',
              'amountUsdCents': 2999,
              'says': 'Billed every month.',
            },
          ],
          'cadenceMeans': 'The only difference is how often you are billed.',
          'introductoryOffer': null,
        },
        'activation': {'open': false, 'says': 'Not now.', 'resolution': 'Talk.'},
        'start': {'says': 'Start by creating your workspace.', 'action': '/x'},
      };

  test('two cadences, one product', () {
    final model = CommercialModel.fromJson(payload());

    expect(model.offers.length, 2);
    // The assertion that matters: the cheaper one is the same product. If this
    // ever fails, some part of the estate has grown a second tier.
    expect(model.offers.map((o) => o.entitlement).toSet().length, 1);
    expect(model.offers.first.entitlement, 'ORCHESTRATE_PLATFORM');
  });

  test('monthly is presented first, whatever order the server sent', () {
    final model = CommercialModel.fromJson(payload());

    // Not cosmetic. Presented annual-first, the larger number is read as the
    // price of Orchestrate and the monthly figure as a discount — which is the
    // opposite of what either one is.
    expect(model.offers.first.period, 'MONTHLY');
    expect(model.offers.last.period, 'ANNUAL');
  });

  test('prices are rendered to the cent, never rounded', () {
    final model = CommercialModel.fromJson(payload());

    expect(model.offerFor('MONTHLY')!.priceLabel, r'$29.99');
    expect(model.offerFor('ANNUAL')!.priceLabel, r'$299.99');

    // A price that renders as $29.9 or $30 reads as a rendering fault, and a
    // price a customer distrusts is worse than one they dislike.
    expect(CommercialOffer.fromJson({'amountUsdCents': 3000}).priceLabel,
        r'$30.00');
    expect(CommercialOffer.fromJson({'amountUsdCents': 2990}).priceLabel,
        r'$29.90');
    expect(CommercialOffer.fromJson({'amountUsdCents': 5}).priceLabel, r'$0.05');
  });

  test('free entry is never one of the paid offers', () {
    final model = CommercialModel.fromJson(payload());

    expect(model.free.amountUsdCents, 0);
    // Kept out of the list so nothing downstream can sort it to the bottom of
    // a ladder and start describing it as what a subscription lapses into.
    expect(model.offers.any((o) => o.amountUsdCents == 0), isFalse);
  });

  test('an older server that publishes nothing sells nothing', () {
    // A deploy order where the app ships before the server does. The right
    // answer is no offers — never one invented at zero.
    final model = CommercialModel.fromJson({'says': 'x'});

    expect(model.offers, isEmpty);
    expect(model.free.amountUsdCents, 0);
    expect(model.free.says, isEmpty);
    // And an absent activation block means selling, matching every other
    // surface, so an older deployment does not shut commerce off for everyone.
    expect(model.activation.open, isTrue);
  });

  test('the retired package vocabulary is gone from customer copy', () {
    // THE DISPATCH LANE IS A DIFFERENT WORD AND IT STAYS.
    //
    // `WorkflowLane`, the governance panel's "which lane and lifecycle stage
    // was applied", and the operation/thread/lane/lifecycle dispatch headers
    // name a real execution concept. This is only about the commercial lane —
    // half of the retired lane x tier package pair.
    //
    // It survived the data-model removal as hardcoded sentences: a live
    // workspace read "Managed execution is running under your lane" on the
    // Plan & billing screen, found on a Pixel after the fields were gone.
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity
          .readAsStringSync()
          .split('\n')
          .where((line) => !line.trimLeft().startsWith('//'))
          .join('\n');
      for (final phrase in const [
        'your lane',
        'same lane',
        'lane + tier',
        'lane and tier',
        'Opportunity · Focused',
      ]) {
        if (source.contains(phrase)) offenders.add('${entity.path}: $phrase');
      }
    }
    expect(offenders, isEmpty,
        reason: 'a package this product no longer sells must not be described '
            'to a customer as the thing they are on:\n${offenders.join('\n')}');
  });

  test('no price is written into the client', () {
    // THE RULE THIS FILE EXISTS FOR.
    //
    // Apple and Google return a localized storefront price and the web page
    // reads the server's. A literal in the app is wrong for most of the world
    // the day it is typed, and wrong everywhere the day the price changes.
    // A money-shaped literal: a decimal amount, or two digits or more. A lone
    // `$1` is a regular-expression group reference, and `$0.00` is a formatter
    // reaching for a zero — neither claims anything about what Orchestrate
    // costs, which is the only thing this guard is about.
    final money =
        RegExp(r'\$(\d{1,3}(?:,\d{3})+(?:\.\d+)?|\d+\.\d+|\d{2,})');
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity
          .readAsStringSync()
          .split('\n')
          .where((line) => !line.trimLeft().startsWith('//'))
          .join('\n');
      for (final match in money.allMatches(source)) {
        final amount = match.group(1)!.replaceAll(',', '');
        if (double.parse(amount) == 0) continue;
        offenders.add('${entity.path}: ${match.group(0)}');
      }
    }
    expect(offenders, isEmpty,
        reason: 'a price must come from the store or the server, never from '
            'the client:\n${offenders.join('\n')}');
  });
}
