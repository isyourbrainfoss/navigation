import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../core/maneuver.dart';
import '../core/voice_timing.dart';
import '../models/nav_progress.dart';

enum VoiceGate { far, near, now, arrived }

/// Spoken turn-by-turn. Uses flutter_tts, then speech-dispatcher on Linux.
class VoiceService extends ChangeNotifier {
  VoiceService() {
    _init();
  }

  final FlutterTts _tts = FlutterTts();
  bool _ready = false;
  bool _spokeOk = false;
  bool muted = false;
  VoiceGate? _lastGate;
  int _lastInstruction = -1;
  String? _lastUtterance;
  bool _saidApproaching = false;

  /// Set when Linux has no TTS engine and both spd-say and espeak fail.
  String? unavailableReason;

  /// True if TTS init succeeded or a later speak actually ran.
  bool get voiceAvailable => _ready || _spokeOk;

  Future<void> _init() async {
    try {
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.52);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      _ready = true;
    } catch (e) {
      debugPrint('TTS init failed, will use spd-say: $e');
      _ready = false;
      if (Platform.isLinux && !await _linuxBackendPresent()) {
        _setUnavailable('Voice unavailable (install speech-dispatcher)');
      }
    }
    notifyListeners();
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }

  Future<void> speakRaw(String text) async {
    if (muted) return;
    final t = text.trim();
    if (t.isEmpty || t == _lastUtterance) return;
    _lastUtterance = t;
    if (_ready) {
      try {
        await _tts.speak(t);
        _markSpoke();
        return;
      } catch (e) {
        debugPrint('tts.speak failed: $e');
        _ready = false;
      }
    }
    if (Platform.isLinux) {
      if (await _linuxSpeak(t)) {
        _markSpoke();
        return;
      }
      _setUnavailable('Voice unavailable (install speech-dispatcher)');
    }
  }

  Future<void> onProgress({
    required NavProgress progress,
    required bool metric,
    required bool enabled,
    String modeName = 'drive',
    double speedMps = 0,
  }) async {
    if (!enabled || muted) return;
    if (progress.arrived) {
      if (_lastGate != VoiceGate.arrived) {
        _lastGate = VoiceGate.arrived;
        await speakRaw('You have arrived');
      }
      return;
    }
    if (progress.approaching && !_saidApproaching) {
      _saidApproaching = true;
      final side = progress.destinationSide;
      final extra = side == null ? '' : ' on the $side';
      await speakRaw('Your destination is ahead$extra');
    }
    if (progress.offRoute) return;
    final step = progress.current;
    if (step == null) return;
    if (!Maneuver.isTurn(type: step.type)) return;

    if (progress.instructionIndex != _lastInstruction) {
      _lastInstruction = progress.instructionIndex;
      _lastGate = null;
    }

    final m = progress.metersToNextManeuver;
    final far = VoiceTiming.farMeters(modeName: modeName, speedMps: speedMps);
    final near = VoiceTiming.nearMeters(modeName: modeName, speedMps: speedMps);
    final now = VoiceTiming.nowMeters(modeName: modeName, speedMps: speedMps);
    VoiceGate? gate;
    if (m <= now) {
      gate = VoiceGate.now;
    } else if (m <= near) {
      gate = VoiceGate.near;
    } else if (m <= far) {
      gate = VoiceGate.far;
    }
    if (gate == null || gate == _lastGate) return;
    // Only announce a gate once, and only moving closer.
    if (_lastGate != null && gate.index < _lastGate!.index) return;
    _lastGate = gate;
    var phrase = Maneuver.spoken(
      text: step.text,
      metersToManeuver: m,
      metric: metric,
      now: gate == VoiceGate.now,
    );
    if (gate == VoiceGate.now && progress.thenNext != null) {
      phrase = '$phrase, then ${progress.thenNext!.text}';
    }
    await speakRaw(phrase);
  }

  Future<void> announceReroute() async {
    reset();
    await speakRaw('Recalculating route');
  }

  void reset() {
    _lastGate = null;
    _lastInstruction = -1;
    _lastUtterance = null;
    _saidApproaching = false;
  }

  void _markSpoke() {
    _spokeOk = true;
    _setUnavailable(null);
  }

  void _setUnavailable(String? reason) {
    if (unavailableReason == reason) return;
    unavailableReason = reason;
    notifyListeners();
  }

  Future<bool> _linuxBackendPresent() async {
    return await _binExists('spd-say') || await _binExists('espeak');
  }

  Future<bool> _linuxSpeak(String text) async {
    try {
      await Process.start('spd-say', [text], mode: ProcessStartMode.detached);
      return true;
    } catch (_) {}
    try {
      final result = await Process.run('espeak', [text]);
      return result.exitCode == 0;
    } catch (e) {
      debugPrint('No TTS backend: $e');
    }
    return false;
  }

  Future<bool> _binExists(String name) async {
    for (final dir in const ['/usr/bin', '/usr/local/bin', '/bin', '/app/bin']) {
      if (File('$dir/$name').existsSync()) return true;
    }
    try {
      final result = await Process.run('which', [name]);
      return result.exitCode == 0 && '${result.stdout}'.trim().isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}
