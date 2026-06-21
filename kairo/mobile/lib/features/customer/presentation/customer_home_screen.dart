import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/matching/matching_engine.dart';
import '../../../core/payments/earnings_calculator.dart';
import '../../../shared/theme/kairo_theme.dart';

class CustomerHomeScreen extends ConsumerStatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  ConsumerState<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends ConsumerState<CustomerHomeScreen> {
  final _pickupCtrl = TextEditingController(text: 'Denver Union Station');
  final _dropoffCtrl = TextEditingController(text: 'Boulder, CO');
  bool _loading = false;
  String? _rideId;

  @override
  void dispose() {
    _pickupCtrl.dispose();
    _dropoffCtrl.dispose();
    super.dispose();
  }

  Future<void> _requestRide() async {
    setState(() => _loading = true);
    try {
      final engine = ref.read(matchingEngineProvider);
      final ride = await engine.requestJob(
        pickup: _pickupCtrl.text,
        dropoff: _dropoffCtrl.text,
        distanceKm: 42,
        durationMin: 38,
      );
      setState(() => _rideId = ride.id);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fare = EarningsCalculator.calculate(distanceKm: 42, durationMin: 38);

    return Scaffold(
      appBar: AppBar(title: const Text('Request ride')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: _pickupCtrl, decoration: const InputDecoration(labelText: 'Pickup')),
            TextField(controller: _dropoffCtrl, decoration: const InputDecoration(labelText: 'Dropoff')),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                title: const Text('1% platform fee — shown upfront'),
                subtitle: Text(
                  'Total \$${fare.customerTotalUsd.toStringAsFixed(2)} '
                  '(fee \$${fare.customerFeeUsd.toStringAsFixed(2)})',
                ),
                trailing: const Icon(Icons.info_outline, color: KairoColors.customerFee),
              ),
            ),
            const Spacer(),
            if (_rideId != null) Text('Ride $_rideId matching…'),
            FilledButton(
              onPressed: _loading ? null : _requestRide,
              child: Text(_loading ? 'Matching…' : 'Request ride / delivery'),
            ),
          ],
        ),
      ),
    );
  }
}
