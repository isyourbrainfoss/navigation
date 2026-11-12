import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navigation/features/map/widgets/tiles_failing_banner.dart';

void main() {
  testWidgets('tile failure banner does not claim the device is offline',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: TilesFailingBanner())),
    );

    expect(find.text(TilesFailingBanner.message), findsOneWidget);
    final copy = TilesFailingBanner.message.toLowerCase();
    // We only know tile fetches failed, not that the network is down.
    expect(copy, isNot(contains('no internet')));
    expect(copy, isNot(contains('no connection')));
    expect(copy, isNot(contains('offline')));
    expect(copy, contains('already viewed'));
    expect(find.byIcon(Icons.cloud_off), findsNothing);
  });
}
