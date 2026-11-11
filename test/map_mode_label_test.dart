import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navigation/features/map/widgets/map_controls.dart';

void main() {
  testWidgets('MapModeLabel shows the mode', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: MapModeLabel(text: 'Course up'))),
      ),
    );
    expect(find.byKey(const Key('map_mode_label')), findsOneWidget);
    expect(find.text('Course up'), findsOneWidget);
  });
}
