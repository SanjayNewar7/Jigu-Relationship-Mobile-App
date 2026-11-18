class DateInvitation {
  DateInvitation(this.data);
  final Map<String, dynamic> data;
  String get id => data['id'];
  String get creator => data['creator_id'];
  String get venue => data['venue'];
  String? get heading => data['heading'] as String?;
  String get address => data['address'];
  String get dress => data['dress_style'];
  String get message => data['message'];
  String get status => data['status'];
  double? get latitude => (data['latitude'] as num?)?.toDouble();
  double? get longitude => (data['longitude'] as num?)?.toDouble();
  String? get selfiePath => data['selfie_path'];
  bool get canComplete =>
      ['pending', 'accepted'].contains(status) &&
      !startsAt.isAfter(DateTime.now());
  DateTime get startsAt => DateTime.parse(data['starts_at']).toLocal();
}
