import 'support_message.dart';

class SupportSession {
  final String? sessionId;
  final List<SupportMessage> messages;
  final bool isLoading;
  final bool publicMode;
  final String? status;
  final String? category;
  final String? priority;
  final bool caseCreated;
  final String? caseId;

  const SupportSession({
    this.sessionId,
    this.messages = const [],
    this.isLoading = false,
    this.publicMode = true,
    this.status,
    this.category,
    this.priority,
    this.caseCreated = false,
    this.caseId,
  });

  SupportSession copyWith({
    Object? sessionId = _unset,
    List<SupportMessage>? messages,
    bool? isLoading,
    bool? publicMode,
    Object? status = _unset,
    Object? category = _unset,
    Object? priority = _unset,
    bool? caseCreated,
    Object? caseId = _unset,
  }) {
    return SupportSession(
      sessionId:
          identical(sessionId, _unset) ? this.sessionId : sessionId as String?,
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      publicMode: publicMode ?? this.publicMode,
      status: identical(status, _unset) ? this.status : status as String?,
      category:
          identical(category, _unset) ? this.category : category as String?,
      priority:
          identical(priority, _unset) ? this.priority : priority as String?,
      caseCreated: caseCreated ?? this.caseCreated,
      caseId: identical(caseId, _unset) ? this.caseId : caseId as String?,
    );
  }
}

const Object _unset = Object();
