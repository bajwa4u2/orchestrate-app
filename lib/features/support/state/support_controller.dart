import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
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
    if (trimmed.length > 5000) {
      _session = _session.copyWith(
        messages: [
          ..._session.messages,
          const SupportMessage(
            role: 'system',
            content: 'Messages must be 5,000 characters or fewer.',
          ),
        ],
      );
      notifyListeners();
      return;
    }

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
              sessionToken: _session.sessionToken,
            );

      final systemMessage = SupportMessage.fromIntakeResponse(data);
      final updated = List<SupportMessage>.from(nextMessages)
        ..add(systemMessage);

      _session = _session.copyWith(
        sessionId: data['sessionId']?.toString() ?? _session.sessionId,
        sessionToken:
            data['sessionToken']?.toString() ?? _session.sessionToken,
        messages: updated,
        isLoading: false,
        status: data['status']?.toString(),
        category: data['category']?.toString(),
        priority: data['priority']?.toString(),
        caseCreated: data['caseCreated'] == true,
        caseId: data['caseId']?.toString(),
      );
      notifyListeners();
    } catch (error) {
      final updated = List<SupportMessage>.from(nextMessages)
        ..add(
          SupportMessage(
            role: 'system',
            content: _supportErrorMessage(error),
          ),
        );

      _session = _session.copyWith(
        messages: updated,
        isLoading: false,
      );
      notifyListeners();
    }
  }

  String _supportErrorMessage(Object error) {
    if (error is ApiException) {
      if (error.statusCode == 403) {
        return publicMode
            ? 'This support session can’t be continued from here. Start a new message and we’ll route it safely.'
            : 'This support session does not belong to the signed-in client.';
      }
      if (error.statusCode == 401) {
        return publicMode
            ? 'This support session needs a valid continuation token. Start a new message if the session was lost.'
            : 'Your session expired. Sign in again to continue support.';
      }
      if (error.statusCode == 429) {
        return 'Too many support requests were sent in a short period. Try again shortly.';
      }
      if (error.message.isNotEmpty) return error.message;
    }
    return 'We could not process this at the moment. Please try again.';
  }
}
