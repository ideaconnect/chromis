import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/responsive_center.dart';
import 'iap.dart';

/// Go Pro / paywall: the one-time `chromis_pro_mode` purchase that removes all
/// ads, with Restore. Purchase delivery + acknowledgement is handled app-wide
/// by [purchaseDeliveryProvider]; this screen just launches buy/restore and
/// reflects the entitlement.
class GoProScreen extends ConsumerWidget {
  const GoProScreen({super.key});

  void _snack(BuildContext context, String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final isPro = ref.watch(proEntitledProvider).asData?.value ?? false;
    final product = ref.watch(proProductProvider).asData?.value;

    // Play reports a declined card or an unavailable service asynchronously,
    // long after buy() returns - so the error arrives on the stream, not from
    // the call. Previously nothing listened and the paywall just sat there.
    ref.listen<String?>(purchaseErrorProvider, (_, message) {
      if (message == null || !context.mounted) return;
      _snack(context, message);
      ref.read(purchaseErrorProvider.notifier).clear();
    });

    Future<void> buy() async {
      if (product == null) {
        _snack(
          context,
          'Purchases are temporarily unavailable - please try again later.',
        );
        return;
      }
      final bool started;
      try {
        started = await ref.read(iapServiceProvider).buy(product);
      } catch (_) {
        if (context.mounted) {
          _snack(context, "Couldn't start the purchase - please try again.");
        }
        return;
      }
      // false means Play never opened its sheet - most often because this
      // account already owns the product, which Restore fixes.
      if (!started && context.mounted) {
        _snack(
          context,
          "Couldn't start the purchase - if you already bought Pro, "
          'tap Restore purchase.',
        );
      }
    }

    Future<void> restore() async {
      // Said BEFORE the await: restorePurchases() can take seconds, and can
      // throw (offline is the common case), which used to leave the tap with
      // no acknowledgement at all.
      _snack(context, 'Checking for a previous purchase…');
      try {
        await ref.read(iapServiceProvider).restore();
      } catch (_) {
        if (context.mounted) {
          _snack(
            context,
            "Couldn't reach Google Play - check your connection and try again.",
          );
        }
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Go Pro')),
      // Capped so the hero card, the benefit rows and the buy button stay one
      // readable column instead of a screen-wide band with the price at one
      // end and the icon at the other.
      body: ResponsiveCenter(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: tokens.heroGradient,
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.workspace_premium, color: Colors.white, size: 34),
                  SizedBox(height: 12),
                  Text(
                    'Remove ads forever',
                    style: TextStyle(
                      fontFamily: AppFonts.display,
                      fontWeight: FontWeight.w700,
                      fontSize: 22,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'One-time purchase. Every AI feature stays free - no ads, '
                    'no watch-to-run.',
                    style: TextStyle(
                      fontFamily: AppFonts.ui,
                      fontSize: 13,
                      height: 1.45,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _benefit('No banner or full-screen ads'),
            _benefit('Run AI Cut & object removal without a rewarded ad'),
            _benefit('One-time payment - no subscription'),
            _benefit('Supports private, on-device photo editing'),
            const SizedBox(height: 24),
            if (isPro)
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 18,
                ),
                decoration: BoxDecoration(
                  color: AppColors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.green.withValues(alpha: 0.4),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.verified, color: AppColors.green, size: 22),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "You're Pro - ads are off. Thank you!",
                        style: TextStyle(
                          fontFamily: AppFonts.ui,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              FilledButton(
                onPressed: buy,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.cyan,
                  foregroundColor: AppColors.cutoutInk,
                  minimumSize: const Size.fromHeight(52),
                ),
                child: Text(
                  product == null ? 'Go Pro' : 'Upgrade - ${product.price}',
                  style: const TextStyle(
                    fontFamily: AppFonts.display,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: restore,
                child: const Text('Restore purchase'),
              ),
              const SizedBox(height: 8),
              Text(
                product == null
                    ? 'One-time purchase · temporarily unavailable'
                    : 'One-time purchase · restores on any device',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: AppFonts.ui,
                  fontSize: 11,
                  color: AppColors.textFaint,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _benefit(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.check_circle, color: AppColors.green, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontFamily: AppFonts.ui,
              fontSize: 13.5,
              height: 1.4,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    ),
  );
}
