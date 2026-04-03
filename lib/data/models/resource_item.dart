class ResourceItem {
  ResourceItem({required this.id, required this.title, required this.primary, required this.secondary, required this.meta});

  final String id;
  final String title;
  final String primary;
  final String secondary;
  final Map<String, dynamic> meta;

  factory ResourceItem.fromJson(Map<String, dynamic> json, ResourceKind kind) {
    switch (kind) {
      case ResourceKind.client:
        return ResourceItem(
          id: (json['id'] ?? '').toString(),
          title: (json['displayName'] ?? json['legalName'] ?? 'Client').toString(),
          primary: (json['websiteUrl'] ?? json['contactEmail'] ?? (json['industry'] ?? 'Client record')).toString(),
          secondary: _join([
            json['stage'],
            json['countryCode'],
            json['timezone'],
          ]),
          meta: json,
        );
      case ResourceKind.campaign:
        return ResourceItem(
          id: (json['id'] ?? '').toString(),
          title: (json['name'] ?? 'Campaign').toString(),
          primary: (json['status'] ?? 'No status').toString(),
          secondary: _join([
            json['channel'],
            json['objective'],
          ]),
          meta: json,
        );
      case ResourceKind.lead:
        return ResourceItem(
          id: (json['id'] ?? '').toString(),
          title: (json['fullName'] ?? json['email'] ?? 'Lead').toString(),
          primary: (json['companyName'] ?? json['email'] ?? 'Lead record').toString(),
          secondary: _join([
            json['status'],
            json['source'],
          ]),
          meta: json,
        );
      case ResourceKind.reply:
        return ResourceItem(
          id: (json['id'] ?? '').toString(),
          title: (json['fromEmail'] ?? 'Reply').toString(),
          primary: (json['intent'] ?? 'Intent pending').toString(),
          secondary: (json['subjectLine'] ?? json['bodyText'] ?? '').toString(),
          meta: json,
        );
      case ResourceKind.meeting:
        return ResourceItem(
          id: (json['id'] ?? '').toString(),
          title: (json['title'] ?? 'Meeting').toString(),
          primary: (json['status'] ?? 'Unscheduled').toString(),
          secondary: _join([
            json['scheduledAt'],
            json['bookingUrl'],
          ]),
          meta: json,
        );
    }
  }

  static String _join(List<dynamic> parts) {
    final values = parts.where((part) => part != null && part.toString().trim().isNotEmpty).map((part) => part.toString().trim()).toList();
    return values.join(' · ');
  }
}

enum ResourceKind { client, campaign, lead, reply, meeting }
