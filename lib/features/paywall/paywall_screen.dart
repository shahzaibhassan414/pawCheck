import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

typedef RestorePurchasesFn = Future<bool> Function();

Future<bool> _defaultRestorePurchases() async => false;

class _PricingOption {
  const _PricingOption({
    required this.id,
    required this.label,
    required this.price,
    required this.period,
    this.badge,
  });

  final String id;
  final String label;
  final String price;
  final String period;
  final String? badge;
}

const _monthly = _PricingOption(
  id: 'monthly',
  label: 'Monthly',
  price: '\$4.99',
  period: 'per month',
);

const _annual = _PricingOption(
  id: 'annual',
  label: 'Annual',
  price: '\$39.99',
  period: 'per year',
  badge: 'Best value — save 33%',
);

/// Paywall, PRD Milestone 7 ("Free-scan counter... hard paywall screen
/// triggered when the free scan is used... RevenueCat-driven subscription
/// options... Restore purchases flow"). Not one of the "Paw Check claude
/// design" doc's 7 screens (that doc's scope is explicitly Splash/
/// Onboarding/Account+AddPet/Home/Camera/Results/Timeline only) — this
/// screen's look is this build's own extrapolation of the doc's tokens
/// (violet accent, Caprasimo/Figtree, pill shapes, 16px radius), not a
/// spec'd mockup.
///
/// UI-first: RevenueCat isn't wired up yet (still blocked on Milestone 0),
/// so pricing is static mock data and both "Continue" and "Restore
/// purchases" resolve locally instead of hitting a real store. Per this
/// session's decision (free-scan limit is **per install**, not per pet —
/// CLAUDE.md flagged this as an open PRD question), this screen assumes
/// one shared entitlement for the whole account, not one per pet.
/// Popping `true` means "treat the account as subscribed now"; a real
/// RevenueCat integration would await an actual purchase/restore call
/// where [restorePurchases] currently just returns a canned value.
class PaywallScreen extends StatefulWidget {
  const PaywallScreen({
    super.key,
    this.restorePurchases = _defaultRestorePurchases,
  });

  final RestorePurchasesFn restorePurchases;

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  String _selectedId = _annual.id;
  bool _restoring = false;

  void _continue() => Navigator.of(context).pop(true);

  Future<void> _restore() async {
    setState(() => _restoring = true);
    final restored = await widget.restorePurchases();
    if (!mounted) return;
    setState(() => _restoring = false);
    if (restored) {
      Navigator.of(context).pop(true);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No previous purchases found.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          key: const Key('paywall_close_button'),
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppTheme.spaceLg),
          children: [
            Icon(Icons.favorite_rounded, color: colorScheme.primary, size: 48),
            const SizedBox(height: AppTheme.spaceMd),
            Text("You've used your free scan", style: textTheme.headlineSmall),
            const SizedBox(height: AppTheme.spaceSm),
            Text(
              'Subscribe to PawCheck Premium for unlimited scans across '
              'all your pets.',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppTheme.spaceXl),
            _PricingCard(
              key: const Key('paywall_option_monthly'),
              option: _monthly,
              selected: _selectedId == _monthly.id,
              onTap: () => setState(() => _selectedId = _monthly.id),
            ),
            const SizedBox(height: AppTheme.spaceMd),
            _PricingCard(
              key: const Key('paywall_option_annual'),
              option: _annual,
              selected: _selectedId == _annual.id,
              onTap: () => setState(() => _selectedId = _annual.id),
            ),
            const SizedBox(height: AppTheme.spaceXl),
            ElevatedButton(
              key: const Key('paywall_continue_button'),
              onPressed: _continue,
              child: const Text('Continue'),
            ),
            const SizedBox(height: AppTheme.spaceSm),
            Center(
              child: TextButton(
                key: const Key('paywall_restore_button'),
                onPressed: _restoring ? null : _restore,
                child: _restoring
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Restore purchases'),
              ),
            ),
            const SizedBox(height: AppTheme.spaceMd),
            Text(
              'Cancel anytime. Payment charged to your App Store account.',
              textAlign: TextAlign.center,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PricingCard extends StatelessWidget {
  const _PricingCard({
    super.key,
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final _PricingOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: selected ? colorScheme.primaryContainer : colorScheme.surface,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppTheme.spaceMd),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(
              color: selected
                  ? colorScheme.primary
                  : colorScheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppTheme.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(option.label, style: textTheme.titleMedium),
                    if (option.badge != null)
                      Text(
                        option.badge!,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    option.price,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    option.period,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
