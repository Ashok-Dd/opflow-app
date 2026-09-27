import 'package:flutter_test/flutter_test.dart';
import 'package:opflow/data/push.dart';
import 'package:opflow/state/session.dart';

void main() {
  test('a tapped notification opens the right screen', () {
    expect(Push.routeFor({'bookingId': 'b1', 'kind': 'reminder'}, Side.patient), '/booking/b1');
    expect(Push.routeFor({'kind': 'system'}, Side.patient), '/messages');
    expect(Push.routeFor({'bookingId': 'b1'}, Side.doctor), '/d/booking/b1');
    expect(Push.routeFor({'kind': 'system'}, Side.doctor), '/d/messages');
    expect(Push.routeFor({'bookingId': 'b1'}, Side.none), isNull);
  });
}
