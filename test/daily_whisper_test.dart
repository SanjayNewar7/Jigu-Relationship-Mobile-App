import 'package:flutter_test/flutter_test.dart';
import 'package:jigulove/models/daily_whisper.dart';

void main() {
  test('daily message is stable throughout a day and changes tomorrow', () {
    final morning = DateTime(2026, 10, 29, 7);
    final evening = DateTime(2026, 10, 29, 23);
    expect(dailyWhisper(morning), dailyWhisper(evening));
    expect(dailyWhisper(morning), isNot(dailyWhisper(DateTime(2026, 10, 30))));
  });
}
