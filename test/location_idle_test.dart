import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:navigation/services/location_service.dart';

void main() {
  LocationFix fixAt(DateTime t) => LocationFix(
        position: const LatLng(52.5, 13.4),
        accuracyMeters: 8,
        timestamp: t,
      );

  test('GPS ticks do not refresh idle; pauseIfIdle stops the stream', () async {
    final t0 = DateTime.utc(2026, 1, 1, 12);
    var now = t0;
    final location = LocationService(clock: () => now);

    location.attachDummySubscription();
    expect(location.isListening, isTrue);

    location.noteUserActivity();
    expect(location.isIdle, isFalse);

    now = t0.add(LocationService.idleAfter - const Duration(seconds: 1));
    location.ingestFix(fixAt(now));
    expect(location.lastFix, isNotNull);
    expect(location.isIdle, isFalse);

    now = t0.add(LocationService.idleAfter + const Duration(seconds: 1));
    expect(location.isIdle, isTrue);

    await location.pauseIfIdle(navigating: false);
    expect(location.isListening, isFalse);
  });

  test('navigating never idles even after the browse timeout', () async {
    final t0 = DateTime.utc(2026, 1, 1, 12);
    var now = t0;
    final location = LocationService(clock: () => now);
    location.attachDummySubscription();
    location.noteUserActivity();
    await location.pauseIfIdle(navigating: true);

    now = t0.add(LocationService.idleAfter * 2);
    location.ingestFix(fixAt(now));
    expect(location.isIdle, isFalse);
    expect(location.isListening, isTrue);
  });
}
