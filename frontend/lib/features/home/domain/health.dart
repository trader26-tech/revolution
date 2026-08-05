/// Domain model mirroring the backend `/health` response.
class Health {
  const Health({required this.status});

  final String status;

  factory Health.fromJson(Map<String, dynamic> json) =>
      Health(status: json['status'] as String? ?? 'unknown');
}
