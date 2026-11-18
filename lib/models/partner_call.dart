class PartnerCall {
  const PartnerCall({
    required this.id,
    required this.callerId,
    required this.kind,
    required this.status,
    required this.createdAt,
    this.acceptedAt,
  });
  final String id, callerId, kind, status;
  final DateTime createdAt;
  final DateTime? acceptedAt;
  bool get terminal => !['ringing', 'accepted'].contains(status);
  factory PartnerCall.fromMap(Map<String, dynamic> row) => PartnerCall(
    id: row['id'] as String,
    callerId: row['caller_id'] as String,
    kind: row['kind'] as String,
    status: row['status'] as String,
    createdAt: DateTime.parse(row['created_at'] as String),
    acceptedAt: DateTime.tryParse(row['accepted_at']?.toString() ?? ''),
  );
}
