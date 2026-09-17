import 'package:flutter_test/flutter_test.dart';

import 'package:nokha_ride/main.dart';

void main() {
  testWidgets('Nokha Ride app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const NokhaRideApp());

    expect(find.text('Nokha Ride'), findsWidgets);
  });
}