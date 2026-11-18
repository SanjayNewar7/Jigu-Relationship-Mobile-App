class RelationshipDays {
  const RelationshipDays({
    required this.days,
    required this.months,
    required this.message,
  });
  final int days, months;
  final String message;
  static const _messages = [
    'Every little beginning becomes a beautiful story.',
    'One month of choosing each other, every day.',
    'The sweetest little things are becoming our story.',
    'Three months of laughter, comfort, and us.',
    'Love looks lovely in all our ordinary moments.',
    'Another month, another chapter to hold close.',
    'Half a year of finding home in each other.',
    'Together makes even simple days feel special.',
    'Our story keeps blooming, one day at a time.',
    'Nine months of little adventures together.',
    'Still my favorite part of every day.',
    'A year is close, and our story keeps growing.',
  ];
  static RelationshipDays? fromDate(DateTime? started, DateTime now) {
    if (started == null) return null;
    final first = DateTime.utc(started.year, started.month, started.day);
    final today = DateTime.utc(now.year, now.month, now.day);
    if (first.isAfter(today)) return null;
    final days = today.difference(first).inDays + 1;
    var months = (today.year - started.year) * 12 + today.month - started.month;
    final lastDay = DateTime(now.year, now.month + 1, 0).day;
    final anniversaryDay = started.day < lastDay ? started.day : lastDay;
    if (now.day < anniversaryDay) months--;
    final years = months ~/ 12;
    final remainingMonths = months % 12;
    final message = years == 0
        ? _messages[remainingMonths]
        : remainingMonths == 0
            ? '$years ${years == 1 ? 'year' : 'years'} of us, and so much more to bloom.'
            : '$years ${years == 1 ? 'year' : 'years'} and '
                '$remainingMonths ${remainingMonths == 1 ? 'month' : 'months'} '
                'of our story together.';
    return RelationshipDays(days: days, months: months, message: message);
  }
}
