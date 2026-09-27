import 'package:flutter_test/flutter_test.dart';
import 'package:opflow/data/places.dart';

void main() {
  test('the nearest listed area is found from a location', () {
    expect(nearestPlace(16.2998, 80.4500).label, 'Brodipet, Guntur');
    expect(nearestPlace(16.50, 80.64).label, 'Vijayawada');
  });

  test('a saved area label maps back to its place', () {
    expect(placeByLabel('Brodipet, Guntur')?.lat, 16.2999);
    expect(placeByLabel('Tenali')?.name, 'Tenali');
    expect(placeByLabel('Somewhere else'), isNull);
  });
}
