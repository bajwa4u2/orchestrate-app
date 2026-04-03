class ControlOverview {
  ControlOverview({
    required this.systemPhase,
    required this.systemPosture,
    required this.totals,
    required this.today,
    required this.execution,
    required this.deliverability,
    required this.alerts,
  });

  final String systemPhase;
  final String systemPosture;
  final OverviewTotals totals;
  final OverviewToday today;
  final OverviewExecution execution;
  final OverviewDeliverability deliverability;
  final OverviewAlerts alerts;

  factory ControlOverview.fromJson(Map<String, dynamic> json) {
    return ControlOverview(
      systemPhase: (json['system']?['phase'] ?? 'unknown').toString(),
      systemPosture: (json['system']?['posture'] ?? '').toString(),
      totals: OverviewTotals.fromJson((json['totals'] as Map?)?.cast<String, dynamic>() ?? {}),
      today: OverviewToday.fromJson((json['today'] as Map?)?.cast<String, dynamic>() ?? {}),
      execution: OverviewExecution.fromJson((json['execution'] as Map?)?.cast<String, dynamic>() ?? {}),
      deliverability: OverviewDeliverability.fromJson((json['deliverability'] as Map?)?.cast<String, dynamic>() ?? {}),
      alerts: OverviewAlerts.fromJson((json['alerts'] as Map?)?.cast<String, dynamic>() ?? {}),
    );
  }
}

class OverviewTotals {
  OverviewTotals({required this.organizations, required this.clients, required this.campaigns, required this.leads, required this.messages, required this.replies, required this.meetings});
  final int organizations;
  final int clients;
  final int campaigns;
  final int leads;
  final int messages;
  final int replies;
  final int meetings;
  factory OverviewTotals.fromJson(Map<String, dynamic> json) => OverviewTotals(
    organizations: (json['organizations'] ?? 0) as int,
    clients: (json['clients'] ?? 0) as int,
    campaigns: (json['campaigns'] ?? 0) as int,
    leads: (json['leads'] ?? 0) as int,
    messages: (json['messages'] ?? 0) as int,
    replies: (json['replies'] ?? 0) as int,
    meetings: (json['meetings'] ?? 0) as int,
  );
}

class OverviewToday {
  OverviewToday({required this.sent, required this.replies, required this.booked});
  final int sent;
  final int replies;
  final int booked;
  factory OverviewToday.fromJson(Map<String, dynamic> json) => OverviewToday(
    sent: (json['sent'] ?? 0) as int,
    replies: (json['replies'] ?? 0) as int,
    booked: (json['booked'] ?? 0) as int,
  );
}

class OverviewExecution {
  OverviewExecution({required this.queuedJobs, required this.failedJobs});
  final int queuedJobs;
  final int failedJobs;
  factory OverviewExecution.fromJson(Map<String, dynamic> json) => OverviewExecution(
    queuedJobs: (json['queuedJobs'] ?? 0) as int,
    failedJobs: (json['failedJobs'] ?? 0) as int,
  );
}

class OverviewDeliverability {
  OverviewDeliverability({required this.activeMailboxes, required this.degradedMailboxes});
  final int activeMailboxes;
  final int degradedMailboxes;
  factory OverviewDeliverability.fromJson(Map<String, dynamic> json) => OverviewDeliverability(
    activeMailboxes: (json['activeMailboxes'] ?? 0) as int,
    degradedMailboxes: (json['degradedMailboxes'] ?? 0) as int,
  );
}

class OverviewAlerts {
  OverviewAlerts({required this.open});
  final int open;
  factory OverviewAlerts.fromJson(Map<String, dynamic> json) => OverviewAlerts(open: (json['open'] ?? 0) as int);
}
