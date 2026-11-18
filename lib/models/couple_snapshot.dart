class CoupleSnapshot {
  const CoupleSnapshot(
    this.profile,
    this.moments,
    this.partnerPlace, {
    this.ownPlace,
    this.partnerProfile,
    this.likedMoments = const [],
    this.startedOn,
  });
  final Map<String, dynamic> profile;
  final List<Map<String, dynamic>> moments;
  final Map<String, dynamic>? partnerPlace, ownPlace, partnerProfile;
  final List<Map<String, dynamic>> likedMoments;
  final DateTime? startedOn;
}
