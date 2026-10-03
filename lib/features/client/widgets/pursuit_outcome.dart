import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:orchestrate_app/core/readiness/owner_readiness.dart';

/// WHAT A YES DID, IN ONE LINE (3 Oct 2026).
///
/// A yes to pursue now starts the first note. The server says what happened
/// in the client's own terms: writing to them now, or the one thing the client
/// must do first. Only the client's own action is ever named, and only then is
/// there a button; anything on Orchestrate's side is handled without a word.
void showPursuitOutcome(BuildContext context, Map<String, dynamic> result) {
  if (result['ok'] != true) return;
  final note = (result['note'] as String?)?.trim() ?? '';
  if (note.isEmpty) return;
  final route = (result['waitingRoute'] as String?)?.trim();
  final messenger = ScaffoldMessenger.maybeOf(context);
  final router = GoRouter.maybeOf(context);
  messenger?.showSnackBar(SnackBar(
    content: Text(note),
    action: route != null && route.isNotEmpty && router != null
        ? SnackBarAction(
            label: 'Do it now',
            onPressed: () => router.go(setupRouteFor(route)),
          )
        : null,
  ));
}
