import 'package:flutter/foundation.dart';

/// How many things wait for the owner's yes right now (DD-26).
///
/// Today computes it from what it loaded and publishes it here, so the rail
/// can show the amber count beside "Today" without a second request. Null
/// means not known yet, and the rail shows no badge rather than a guess.
final ValueNotifier<int?> todayYesCount = ValueNotifier<int?>(null);
