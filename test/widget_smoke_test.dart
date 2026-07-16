import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navigation/core/constants.dart';
import 'package:navigation/core/theme/navigation_theme.dart';

void main() {
  testWidgets('theme and constants load', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: NavigationTheme.light(),
        darkTheme: NavigationTheme.dark(),
        home: const Scaffold(
          body: Center(child: Text(AppConstants.appName)),
        ),
      ),
    );
    expect(find.text(AppConstants.appName), findsOneWidget);
  });
}
