import 'package:flutter_test/flutter_test.dart';
import 'package:opflow/data/places.dart';

void main() {
  test('distance between two points in km', () {
    // Guntur to Vijayawada is about 30 km in a straight line.
    final km = kmBetween(16.3067, 80.4365, 16.5062, 80.6480);
    expect(km, greaterThan(28));
    expect(km, lessThan(33));
    expect(kmBetween(16.3, 80.4, 16.3, 80.4), 0);
  });

  test('an area label joins the area and its town', () {
    expect(const Place('Brodipet', 16.2999, 80.4498, town: 'Guntur').label, 'Brodipet, Guntur');
    expect(const Place('Guntur', 16.3067, 80.4365).label, 'Guntur');
  });
}
