class SupportMessage {
  final String role;
  final String content;
  final List<String> followUps;
  final bool isEscalated;
  final String? status;
  final String? category;
  final String? priority;
  final bool caseCreated;
  final String? caseId;

  const SupportMessage({
    required this.role,
    required this.content,
    this.followUps = const [],
    this.isEscalated = false,
    this.status,
    this.category,
    this.priority,
    this.caseCreated = false,
    this.caseId,
  });

  factory SupportMessage.fromIntakeResponse(Map<String, dynamic> json) {
    final status = json['status']?.toString();
    return SupportMessage(
      role: 'system',
      content: (json['reply'] ?? '').toString(),
      followUps: (json['questions'] as List?)?.map((e) => e.toString()).toList() ?? const <String>[],
      isEscalated: status == 'escalated',
      status: status,
      category: json['category']?.toString(),
      priority: json['priority']?.toString(),
      caseCreated: json['caseCreated'] == true,
      caseId: json['caseId']?.toString(),
    );
  }
}
