class HealthSnapshot {
  HealthSnapshot({required this.status, required this.timestamp, required this.uptime});

  final String status;
  final String timestamp;
  final String uptime;

  factory HealthSnapshot.fromJson(Map<String, dynamic> json) {
    return HealthSnapshot(
      status: (json['status'] ?? json['ok'] ?? 'unknown').toString(),
      timestamp: (json['timestamp'] ?? '').toString(),
      uptime: (json['uptime'] ?? '').toString(),
    );
  }
}
