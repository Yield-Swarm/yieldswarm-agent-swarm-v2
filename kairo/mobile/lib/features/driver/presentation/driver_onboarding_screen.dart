import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/repositories/identity_repository.dart';
import '../../../shared/providers/session_provider.dart';
import '../../../shared/theme/kairo_theme.dart';

class DriverOnboardingScreen extends ConsumerStatefulWidget {
  const DriverOnboardingScreen({super.key});

  @override
  ConsumerState<DriverOnboardingScreen> createState() =>
      _DriverOnboardingScreenState();
}

class _DriverOnboardingScreenState extends ConsumerState<DriverOnboardingScreen> {
  bool _loading = false;
  bool _telemetryConsent = true;
  bool _fsdConsent = false;
  String? _error;

  Future<void> _register() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(identityRepositoryBoundProvider);
      final identity = await repo.registerRemote();
      await ref.read(sessionProvider.notifier).completeOnboarding(
            identity: identity,
            telemetryConsent: _telemetryConsent,
            fsdTrainingConsent: _fsdConsent,
          );
      if (mounted) context.go('/driver');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kairo Driver')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Drive. Earn 2×.',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Colorado DePIN yield engine — cryptographically identified, '
                'privacy-first telemetry to Mandelbrot Tree of Life.',
                style: TextStyle(color: KairoColors.textMuted),
              ),
              const SizedBox(height: 24),
              _boostCard(),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Signed telemetry'),
                subtitle: const Text('GPS traces for DePIN rewards (required)'),
                value: _telemetryConsent,
                onChanged: (v) => setState(() => _telemetryConsent = v),
              ),
              SwitchListTile(
                title: const Text('FSD training contribution'),
                subtitle: const Text('Anonymized routes for Mandelbrot / Tree of Life'),
                value: _fsdConsent,
                onChanged: (v) => setState(() => _fsdConsent = v),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Colors.redAccent)),
              ],
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _loading || !_telemetryConsent ? null : _register,
                  child: Text(_loading ? 'Creating identity…' : 'Create driver identity'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _boostCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: KairoColors.driverBoost.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.bolt, color: KairoColors.driverBoost, size: 32),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('2× app pay', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  Text('Customers pay 1% fee — you keep the boost'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
