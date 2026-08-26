import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Keep the display awake while navigating (wakelock + Linux screensaver inhibit).
class KeepAwakeService {
  DBusClient? _bus;
  DBusRemoteObject? _screensaver;
  int? _cookie;
  bool _wakelock = false;

  Future<void> setActive(bool active) async {
    if (active) {
      await _enable();
    } else {
      await _disable();
    }
  }

  Future<void> _enable() async {
    try {
      await WakelockPlus.enable();
      _wakelock = true;
    } catch (e) {
      debugPrint('wakelock enable failed: $e');
    }
    if (Platform.isLinux) {
      await _inhibitLinux();
    }
  }

  Future<void> _disable() async {
    if (_wakelock) {
      try {
        await WakelockPlus.disable();
      } catch (_) {}
      _wakelock = false;
    }
    await _uninhibitLinux();
  }

  Future<void> _inhibitLinux() async {
    if (_cookie != null) return;
    try {
      _bus ??= DBusClient.session();
      _screensaver ??= DBusRemoteObject(
        _bus!,
        name: 'org.freedesktop.ScreenSaver',
        path: DBusObjectPath('/org/freedesktop/ScreenSaver'),
      );
      final reply = await _screensaver!.callMethod(
        'org.freedesktop.ScreenSaver',
        'Inhibit',
        const [DBusString('Navigation'), DBusString('Turn-by-turn navigation')],
      );
      final v = reply.returnValues.first;
      if (v is DBusUint32) _cookie = v.value;
    } catch (e) {
      debugPrint('ScreenSaver inhibit failed: $e');
    }
    try {
      _bus ??= DBusClient.session();
      final pm = DBusRemoteObject(
        _bus!,
        name: 'org.freedesktop.PowerManagement',
        path: DBusObjectPath('/org/freedesktop/PowerManagement/Inhibit'),
      );
      await pm.callMethod(
        'org.freedesktop.PowerManagement.Inhibit',
        'Inhibit',
        const [
          DBusString('Navigation'),
          DBusString('Turn-by-turn navigation'),
        ],
      );
    } catch (e) {
      debugPrint('PowerManagement inhibit failed: $e');
    }
  }

  Future<void> _uninhibitLinux() async {
    final cookie = _cookie;
    final ss = _screensaver;
    if (cookie == null || ss == null) return;
    try {
      await ss.callMethod(
        'org.freedesktop.ScreenSaver',
        'UnInhibit',
        [DBusUint32(cookie)],
      );
    } catch (_) {}
    _cookie = null;
  }

  Future<void> dispose() async {
    await _disable();
    await _bus?.close();
  }
}
