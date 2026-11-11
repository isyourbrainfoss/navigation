import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navigation/features/navigate/guidance_banner.dart';

double _luminance(Color c) => c.computeLuminance();

double _contrast(Color a, Color b) {
  final la = _luminance(a), lb = _luminance(b);
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

Widget _host(Widget child, {Brightness brightness = Brightness.dark}) =>
    MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.amber,
          brightness: brightness,
        ),
      ),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(width: 360 - 24, child: child),
        ),
      ),
    );

void main() {
  for (final b in Brightness.values) {
    testWidgets('off-route banner is one compact row on a phone ($b)',
        (tester) async {
      var kept = 0;
      await tester.pumpWidget(_host(
        OffRouteBanner(rerouting: false, onKeepRoute: () => kept++),
        brightness: b,
      ));
      final banner = tester.getSize(find.byKey(const Key('off_route_banner')));
      // The old two-line banner was ~78 dp tall; one row with a 48 dp button.
      expect(banner.height, lessThanOrEqualTo(56));

      final button = find.byKey(const Key('off_route_stay'));
      final size = tester.getSize(button);
      expect(size.height, greaterThanOrEqualTo(48));
      expect(size.width, greaterThanOrEqualTo(64));
      expect(find.text('Keep route'), findsOneWidget);

      // Filled, high-contrast button against the banner.
      final scheme = Theme.of(tester.element(button)).colorScheme;
      expect(
        _contrast(scheme.onTertiaryContainer, scheme.tertiaryContainer),
        greaterThanOrEqualTo(4.5),
      );

      await tester.tap(button);
      expect(kept, 1);
    });
  }

  testWidgets('recalculating text fits without wrapping', (tester) async {
    await tester.pumpWidget(
      _host(OffRouteBanner(rerouting: true, onKeepRoute: () {})),
    );
    expect(find.text('Recalculating…'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('off_route_banner'))).height,
      lessThanOrEqualTo(56),
    );
  });

  test('guidance sizes stay compact but tappable', () {
    expect(GuidanceSizes.iconBox, lessThanOrEqualTo(56));
    expect(GuidanceSizes.barButton, greaterThanOrEqualTo(48));
    expect(GuidanceSizes.distanceFont, greaterThanOrEqualTo(30));
  });
}
