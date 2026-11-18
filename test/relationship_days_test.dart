import 'package:flutter_test/flutter_test.dart';
import 'package:jigulove/models/relationship_days.dart';

void main() {
  test('inclusive day count survives leap day and year boundary', () {
    final first = DateTime(2024, 2, 29);
    expect(RelationshipDays.fromDate(first, DateTime(2024, 2, 29))!.days, 1);
    expect(RelationshipDays.fromDate(first, DateTime(2024, 3, 1))!.days, 2);
    expect(RelationshipDays.fromDate(first, DateTime(2025, 2, 28))!.months, 12);
  });
  test('monthly message changes on the monthly anniversary', () {
    final first = DateTime(2026, 1, 31);
    final before = RelationshipDays.fromDate(first, DateTime(2026, 2, 27))!;
    final after = RelationshipDays.fromDate(first, DateTime(2026, 2, 28))!;
    expect(before.months, 0);
    expect(after.months, 1);
    expect(after.message, isNot(before.message));
    expect(RelationshipDays.fromDate(first, DateTime(2026, 1, 30)), isNull);
  });
  test('caption includes years after the first anniversary', () {
    final count = RelationshipDays.fromDate(
      DateTime(2025, 1, 15), DateTime(2026, 11, 7),
    )!;
    expect(count.days, 662);
    expect(count.months, 21);
    expect(count.message, contains('1 year and 9 months'));
  });
}
