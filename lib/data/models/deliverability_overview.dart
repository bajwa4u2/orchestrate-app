class DeliverabilityOverview {
  DeliverabilityOverview(
      {required this.activeMailboxes, required this.degradedMailboxes});

  final int activeMailboxes;
  final int degradedMailboxes;

  factory DeliverabilityOverview.fromJson(Map<String, dynamic> json) {
    return DeliverabilityOverview(
      activeMailboxes: (json['activeMailboxes'] ?? 0) as int,
      degradedMailboxes: (json['degradedMailboxes'] ?? 0) as int,
    );
  }
}
