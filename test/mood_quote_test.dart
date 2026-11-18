import 'package:flutter_test/flutter_test.dart';
import 'package:jigulove/features/home/models/couple_quote_bank.dart';
import 'package:jigulove/utils/location_label.dart';

void main() {
  test('eight moods supply at least 250 distinct couple lines', () {
    final lines = JiguMood.values.expand(quotesForMood).toList();
    expect(JiguMood.values.length, 8);
    expect(lines.length, greaterThanOrEqualTo(250));
    expect(lines.toSet().length, lines.length);
  });

  test('the daily thought responds to mood and a new day', () {
    final today = DateTime(2026, 11, 7);
    expect(quoteForDay(JiguMood.loved, today),
        isNot(quoteForDay(JiguMood.missing, today)));
    expect(quoteForDay(JiguMood.loved, today),
        isNot(quoteForDay(JiguMood.loved, today.add(const Duration(days: 1)))));
  });

  test('location age changes units at minute hour and day boundaries', () {
    expect(timeAgo(const Duration(seconds: 40)), '40 sec ago');
    expect(timeAgo(const Duration(minutes: 59)), '59 min ago');
    expect(timeAgo(const Duration(hours: 1)), '1 hour ago');
    expect(timeAgo(const Duration(hours: 23)), '23 hours ago');
    expect(timeAgo(const Duration(hours: 24)), '1 day ago');
    expect(timeAgo(const Duration(hours: 223)), '9 days ago');
  });
}
