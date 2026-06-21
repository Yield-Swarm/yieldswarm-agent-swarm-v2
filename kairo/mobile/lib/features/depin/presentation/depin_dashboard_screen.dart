import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../../shared/providers/session_provider.dart';
import '../../../shared/theme/kairo_theme.dart';

final contributionProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final dio = ref.watch(dioProvider);
  final session = ref.watch(sessionProvider);
  final driverId = session.identity?.driverId;
  if (driverId == null) return {};
  final res = await dio.get<Map<String, dynamic>>(
    '/drivers/$driverId/contribution',
    queryParameters: {'trip_fare_usd': 24.5},
  );
  return res.data ?? {};
});

final depinStatusProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final dio = ref.watch(dioProvider);
  final res = await dio.get<Map<String, dynamic>>('/depin/status');
  return res.data ?? {};
});

class DepinDashboardScreen extends ConsumerWidget {
  const DepinDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contribution = ref.watch(contributionProvider);
    final depin = ref.watch(depinStatusProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('DePIN earnings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          depin.when(
            data: (d) => Card(
              child: ListTile(
                title: const Text('Network status'),
                subtitle: Text(d['message']?.toString() ?? 'Unknown'),
                trailing: Icon(
                  d['live'] == true ? Icons.cloud_done : Icons.cloud_off,
                  color: d['live'] == true ? KairoColors.driverBoost : KairoColors.textMuted,
                ),
              ),
            ),
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('DePIN error: $e'),
          ),
          const SizedBox(height: 12),
          contribution.when(
            data: (c) {
              final data = c['data'] as Map<String, dynamic>? ?? c;
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Your contribution', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Text('App earnings: \$${data['app_earnings_usd'] ?? '0'}'),
                      Text('DePIN rewards: \$${data['depin_rewards_usd'] ?? '0'}'),
                      Text('Packets: ${data['total_packets'] ?? 0}'),
                      Text('Mandelbrot nodes: ${data['mandelbrot_nodes'] ?? 0}'),
                      const SizedBox(height: 8),
                      const Text('HNT / GRASS / IoTeX projections feed Helix Chain'),
                    ],
                  ),
                ),
              );
            },
            loading: () => const CircularProgressIndicator(),
            error: (e, _) => Text('Contribution error: $e'),
          ),
        ],
      ),
    );
  }
}
