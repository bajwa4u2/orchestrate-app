import 'package:flutter/foundation.dart';

import '../models/support_message.dart';
import '../models/support_session.dart';
import '../services/support_service.dart';

class SupportController extends ChangeNotifier {
  final SupportService service;
  final bool publicMode;
  final String? sourcePage;
  final String? inquiryTypeHint;

  SupportSession _session;
  SupportSession get session => _session;

  SupportController({
    required this.service,
    required this.publicMode,
    this.sourcePage,
    this.inquiryTypeHint,
  }) : _session = SupportSession(publicMode: publicMode);

  Future<void> sendMessage({
    required String message,
    String? name,
    String? email,
  }) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty || _session.isLoading) return;

    final nextMessages = List<SupportMessage>.from(_session.messages)
      ..add(
        SupportMessage(
          role: 'user',
          content: trimmed,
        ),
      );

    _session = _session.copyWith(
      messages: nextMessages,
      isLoading: true,
    );
    notifyListeners();

    try {
      final data = _session.sessionId == null
          ? await service.createSession(
              message: trimmed,
              publicMode: publicMode,
              name: name,
              email: email,
              sourcePage: sourcePage,
              inquiryTypeHint: inquiryTypeHint,
            )
          : await service.reply(
              sessionId: _session.sessionId!,
              message: trimmed,
              publicMode: publicMode,
            );

      final systemMessage = SupportMessage.fromIntakeResponse(data);
      final updated = List<SupportMessage>.from(nextMessages)
        ..add(systemMessage);

      _session = _session.copyWith(
        sessionId: data['sessionId']?.toString() ?? _session.sessionId,
        messages: updated,
        isLoading: false,
        status: data['status']?.toString(),
        category: data['category']?.toString(),
        priority: data['priority']?.toString(),
        caseCreated: data['caseCreated'] == true,
        caseId: data['caseId']?.toString(),
      );
      notifyListeners();
    } catch (_) {
      final updated = List<SupportMessage>.from(nextMessages)
        ..add(
          const SupportMessage(
            role: 'system',
            content:
                'We couldn’t process this at the moment. Please try again.',
          ),
        );

      _session = _session.copyWith(
        messages: updated,
        isLoading: false,
      );
      notifyListeners();
    }
  }
}
