import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kairo_mobile/app.dart';
import 'package:kairo_mobile/core/config/app_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('Kairo app boots onboarding', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(
              apiBaseUrl: 'http://localhost:8080/api/kairo',
              flavor: 'test',
              mapboxToken: '',
              telemetryBatchSize: 5,
              telemetryIntervalSeconds: 30,
              coloradoBounds: ColoradoBounds.defaults,
            ),
          ),
        ],
        child: const KairoApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Drive. Earn 2×'), findsOneWidget);
  });
}
