import 'package:flutter_test/flutter_test.dart';
import 'package:navigation/core/voice_timing.dart';

void main() {
  test('walk far-gate is not the same meters as a 30 m/s drive', () {
    final walk = VoiceTiming.farMeters(modeName: 'walk', speedMps: 1.4);
    final drive = VoiceTiming.farMeters(modeName: 'drive', speedMps: 30);
    expect(walk, 80);
    expect(drive, 600);
    expect(drive, isNot(walk));
    expect(drive, greaterThan(walk));
  });

  test('drive now-gate clamps and scales with speed', () {
    final slow = VoiceTiming.nowMeters(modeName: 'drive', speedMps: 2);
    final fast = VoiceTiming.nowMeters(modeName: 'drive', speedMps: 30);
    expect(slow, 25);
    expect(fast, 60);
  });
}
