import 'package:flutter_test/flutter_test.dart';
import 'package:jigulove/services/date_heading_service.dart';

void main() {
  const service = DateHeadingService();
  test('cafe headings respond to the place and time', () {
    final morning = service.suggest('Cafe Daily', 'Dining', DateTime(2026, 11, 9, 10));
    final evening = service.suggest('Cafe Daily', 'Dining', DateTime(2026, 11, 9, 19));
    expect(morning.first, 'Coffee date at Cafe Daily');
    expect(evening, contains('An evening at Cafe Daily'));
  });
  test('manual place kind drives varied headings', () {
    expect(service.suggest('Narayani River', 'Our place', DateTime(2026, 11, 9, 15)).first,
        contains('water'));
    expect(service.suggest('Hill View', 'Hills', DateTime(2026, 11, 9, 15)).first,
        'A view from Hill View');
    expect(service.suggest('My Spot', 'Bike ride', DateTime(2026, 11, 9, 15)).first,
        contains('Ride'));
  });
}
