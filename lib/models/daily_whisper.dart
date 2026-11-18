const _dailyWhispers = [
  'Every ordinary day feels sweeter with you.',
  'You are my favorite part of today.',
  'A little love makes this day ours.',
  'I am glad our stories found each other.',
  'Today is lovelier because we share it.',
  'You make the little things feel golden.',
  'Another day, another reason to choose us.',
  'Even from afar, we share this day.',
  'The best part of this day is us.',
  'Here is to all our little moments.',
  'With you, today feels like a gift.',
  'Love grows in our everyday moments.',
  'I carry a little bit of you everywhere.',
  'Every sunrise gives us another memory.',
  'Our story gets sweeter one day at a time.',
  'You make today feel wonderfully ours.',
];

String dailyWhisper(DateTime date) {
  final day = DateTime.utc(date.year, date.month, date.day);
  return _dailyWhispers[day.millisecondsSinceEpoch ~/
      Duration.millisecondsPerDay %
      _dailyWhispers.length];
}
