import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/depin/telemetry_collector.dart';
import '../../../core/matching/matching_engine.dart';
import '../../../core/payments/earnings_calculator.dart';
import '../../../shared/providers/session_provider.dart';
import '../../../shared/theme/kairo_theme.dart';

class DriverHomeScreen extends ConsumerStatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  ConsumerState<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends ConsumerState<DriverHomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(telemetryCollectorProvider.notifier).start();
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final telemetry = ref.watch(telemetryCollectorProvider);
    final preview = EarningsCalculator.calculate(distanceKm: 12.4, durationMin: 22);
    final earnings = EarningsCalculator.summarizeTrip(preview);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kairo Driver'),
        actions: [
          TextButton(onPressed: () => context.go('/depin'), child: const Text('DePIN')),
          TextButton(onPressed: () => context.go('/customer'), child: const Text('Ride')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              title: Text(session.identity?.driverId ?? 'Driver'),
              subtitle: Text(
                '${session.identity?.iotexAddress ?? ''}\n'
                '${session.isAvailable ? 'Available' : 'Offline'}',
              ),
              trailing: Switch(
                value: session.isAvailable,
                onChanged: (v) => ref.read(sessionProvider.notifier).setAvailability(v),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _earningsHero(earnings),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Telemetry pipeline', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text('Pending: ${telemetry.pendingCount}'),
                  Text('Submitted: ${telemetry.totalSubmitted}'),
                  if (telemetry.lastFlushAt != null)
                    Text('Last flush: ${telemetry.lastFlushAt}'),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: () => ref.read(telemetryCollectorProvider.notifier).flush(),
                    child: const Text('Flush signed batch'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _earningsHero(EarningsSummary earnings) {
    return Card(
      color: KairoColors.driverBoost.withOpacity(0.08),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Sample trip earnings', style: TextStyle(color: KairoColors.textMuted)),
            Text(
              '\$${earnings.totalUsd.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
            ),
            Text('+ \$${earnings.twoXBoostUsd.toStringAsFixed(2)} from 2× boost'),
            Text('DePIN est. \$${earnings.depinRewardsUsd.toStringAsFixed(4)}'),
          ],
        ),
      ),
    );
  }
}
