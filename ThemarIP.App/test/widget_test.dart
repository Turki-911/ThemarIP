import 'package:flutter_test/flutter_test.dart';
import 'package:themarip_app/main.dart';

void main() {
  testWidgets('App loads BMPF main screen', (WidgetTester tester) async {
    await tester.pumpWidget(const BmpfApp());
    await tester.pumpAndSettle();
    expect(find.byType(BmpfApp), findsOneWidget);
  });
}
