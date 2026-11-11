import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:navigation/providers/app_providers.dart';
import 'package:navigation/services/routing_service.dart';

void main() {
  test('routing errors are phrased for a driver', () {
    expect(
      friendlyRoutingError(RoutingException('Routing timed out')),
      contains('not answering'),
    );
    expect(
      friendlyRoutingError(TimeoutException('x')),
      contains('not answering'),
    );
    expect(
      friendlyRoutingError(const SocketException('Failed host lookup')),
      contains('No connection'),
    );
    expect(
      friendlyRoutingError(http.ClientException('Connection refused')),
      contains('No connection'),
    );
    expect(
      friendlyRoutingError(RoutingException('No route found')),
      'No route found',
    );
  });
}
