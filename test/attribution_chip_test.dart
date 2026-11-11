import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navigation/core/constants.dart';
import 'package:navigation/features/map/widgets/attribution_chip.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
    home: Scaffold(
      body: Align(alignment: Alignment.bottomRight, child: child),
    ),
  );

  testWidgets('shows visible OSM attribution linking to /copyright', (
    tester,
  ) async {
    final opened = <Uri>[];
    await tester.pumpWidget(
      host(
        AttributionChip(
          text: AppConstants.tileAttributionTopo,
          openUri: (u) async => opened.add(u),
        ),
      ),
    );
    // Visible without any tap.
    expect(
      find.textContaining('© OpenStreetMap contributors', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('OpenTopoMap', findRichText: true),
      findsOneWidget,
    );
    // Tapping the OSM credit opens the copyright page.
    await tester.tapOnText(find.textRange.ofSubstring(osmAttributionText));
    await tester.pump();
    expect(opened, [Uri.parse('https://www.openstreetmap.org/copyright')]);
  });

  testWidgets('collapsed chip shows © and expands on tap', (tester) async {
    var expanded = false;
    await tester.pumpWidget(
      host(
        AttributionChip(
          text: AppConstants.tileAttributionOsm,
          collapsed: true,
          onExpand: () => expanded = true,
        ),
      ),
    );
    expect(find.text('©'), findsOneWidget);
    expect(
      find.textContaining('OpenStreetMap contributors', findRichText: true),
      findsNothing,
    );
    await tester.tap(find.text('©'));
    expect(expanded, isTrue);
  });
}
