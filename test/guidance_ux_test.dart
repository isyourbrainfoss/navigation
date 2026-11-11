import 'package:flutter_test/flutter_test.dart';
import 'package:navigation/features/navigate/guidance_banner.dart';
import 'package:navigation/providers/app_providers.dart';

void main() {
  group('thenLine', () {
    test('lowercases the verb after "Then"', () {
      expect(
        thenLine('Turn left onto Storgata'),
        'Then turn left onto Storgata',
      );
    });
    test('drops a leading "At the end of the road," clause', () {
      expect(
        thenLine('At the end of the road, turn left onto Storgata'),
        'Then turn left onto Storgata',
      );
    });
    test('keeps names and acronyms', () {
      expect(thenLine('E6 towards Trondheim'), 'Then E6 towards Trondheim');
    });
  });

  test('stationary fixes do not count toward off-route', () {
    expect(offRouteFixCounts(null), isTrue);
    expect(offRouteFixCounts(0), isFalse);
    expect(offRouteFixCounts(0.3), isFalse);
    expect(offRouteFixCounts(5), isTrue);
  });

  test('MapSession keeps offRouteConfirmed through copyWith', () {
    const s = MapSession();
    expect(s.offRouteConfirmed, isFalse);
    final c = s.copyWith(offRouteConfirmed: true);
    expect(c.offRouteConfirmed, isTrue);
    expect(c.copyWith(muted: true).offRouteConfirmed, isTrue);
  });
}
