import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';

/// WHAT WENT WRONG, IN THE WORDS OF WHOEVER KNOWS.
///
/// The refused state used to render
///
///     ApiException(statusCode: 403, message: This is work Orchestrate does on
///     behalf of the platform. An operator of a client organisation acts inside
///     that organisation.)
///
/// The backend had written a perfectly good sentence and the console wrapped it
/// in a Dart class name and an HTTP status code before showing it to a person.
/// Worse, it offered "Try again" — on a refusal, which will refuse again, every
/// time, for the same reason.
///
/// Two situations, two shapes. Something is broken and retrying is reasonable;
/// or something was refused, and what a person needs is the reason, not a
/// button that repeats the question.
class OpsFailure extends StatelessWidget {
  const OpsFailure({super.key, required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  /// Whether this is a refusal rather than a failure.
  static bool isRefusal(Object error) =>
      error is ApiException && (error.statusCode == 401 || error.statusCode == 403);

  /// The message somebody wrote, with the machinery stripped off.
  static String readable(Object error) {
    if (error is ApiException) {
      final message = error.message.trim();
      if (message.isNotEmpty && message != 'Request failed') return message;
      return 'The request did not go through.';
    }
    // ANYTHING THAT IS NOT OUR OWN ERROR IS NOT A SENTENCE.
    //
    // A transport failure stringifies as "ClientFailed to fetch, uri=http://…"
    // — a Dart type name run into a message, followed by an internal URL. It
    // rendered exactly like that on screen. Nobody can act on a URI, and the
    // truthful thing to say is short.
    return 'The server did not answer. Nothing has changed.';
  }

  @override
  Widget build(BuildContext context) {
    final refused = isRefusal(error);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              refused ? Icons.lock_outline : Icons.cloud_off_outlined,
              size: 34,
              color: refused ? AppTheme.muted : AppTheme.amber,
            ),
            const SizedBox(height: 14),
            Text(
              refused ? 'You cannot see this' : 'We could not read this',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              readable(error),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 12, color: AppTheme.muted, height: 1.55),
            ),
            const SizedBox(height: 18),
            // A refusal is not retried. Repeating a question that was answered
            // is not an affordance, it is a way of not saying no.
            if (!refused)
              FilledButton(
                onPressed: onRetry,
                style: FilledButton.styleFrom(backgroundColor: AppTheme.accent),
                child: const Text('Try again',
                    style: TextStyle(color: AppTheme.background)),
              ),
          ],
        ),
      ),
    );
  }
}
