String locationLabel(Map<String, dynamic>? place) {
  final time = DateTime.tryParse(place?['updated_at']?.toString() ?? '');
  if (time == null) return 'No location shared yet';
  final age = DateTime.now().difference(time);
  if (age.inSeconds < 5) return 'Location updated just now';
  return 'Last shared ${timeAgo(age)}';
}

String timeAgo(Duration age) {
  if (age.inSeconds < 60) return '${age.inSeconds} sec ago';
  if (age.inMinutes < 60) return '${age.inMinutes} min ago';
  if (age.inHours < 24) {
    final hours = age.inHours;
    return '$hours ${hours == 1 ? 'hour' : 'hours'} ago';
  }
  final days = age.inDays;
  return '$days ${days == 1 ? 'day' : 'days'} ago';
}

String activityLabel(String? timestamp) {
  final time = DateTime.tryParse(timestamp ?? '');
  if (time == null) return 'Activity not shared yet';
  final age = DateTime.now().difference(time);
  if (age.inSeconds < 70) return 'Active now';
  return 'Last active ${timeAgo(age)}';
}
