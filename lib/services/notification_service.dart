import 'dart:io';

import 'package:flutter/foundation.dart';

class NotificationService {
  Future<void> show({required String title, required String body}) async {
    if (Platform.isLinux) {
      try {
        await Process.run('notify-send', ['--app-name=Navigation', title, body]);
      } catch (e) {
        debugPrint('notify-send failed: $e');
      }
    }
  }
}
