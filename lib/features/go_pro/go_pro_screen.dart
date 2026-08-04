import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/responsive_center.dart';
import '../../l10n/app_localizations.dart';
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
    final l10n = AppLocalizations.of(context);
    final isPro = ref.watch(proEntitledProvider).asData?.value ?? false;
    final product = ref.watch(proProductProvider).asData?.value;

    // Play reports a declined card or an unavailable service asynchronously,
    // long after buy() returns - so the error arrives on the stream, not from
    // the call. Previously nothing listened and the paywall just sat there.
    ref.listen<String?>(purchaseErrorProvider, (_, message) {
      if (message == null || !context.mounted) return;
      // Empty means Play reported an error with no text of its own.
      _snack(context, message.isEmpty ? l10n.purchaseFailedGeneric : message);
      ref.read(purchaseErrorProvider.notifier).clear();
    });

    Future<void> buy() async {
      if (product == null) {
        _snack(context, l10n.purchasesUnavailable);
        return;
      }
      final bool started;
      try {
        started = await ref.read(iapServiceProvider).buy(product);
      } catch (_) {
        if (context.mounted) {
          _snack(context, l10n.purchaseStartFailed);
        }
        return;
      }
      // false means Play never opened its sheet - most often because this
      // account already owns the product, which Restore fixes.
      if (!started && context.mounted) {
        _snack(context, l10n.purchaseStartFailedOwned);
      }
    }

    Future<void> restore() async {
      // Said BEFORE the await: restorePurchases() can take seconds, and can
      // throw (offline is the common case), which used to leave the tap with
      // no acknowledgement at all.
      _snack(context, l10n.checkingPreviousPurchase);
      try {
        await ref.read(iapServiceProvider).restore();
      } catch (_) {
        if (context.mounted) {
          _snack(context, l10n.playUnreachable);
        }
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.goPro)),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.workspace_premium,
                    color: context.colors.onAccent,
                    size: 34,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.goProHeroTitle,
                    style: TextStyle(
                      fontFamily: AppFonts.display,
                      fontWeight: FontWeight.w700,
                      fontSize: 22,
                      color: context.colors.onAccent,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.goProHeroBody,
                    style: TextStyle(
                      fontFamily: AppFonts.ui,
                      fontSize: 13,
                      height: 1.45,
                      color: context.colors.onAccent,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _benefit(context, l10n.goProBenefitNoAds),
            _benefit(context, l10n.goProBenefitNoRewarded),
            _benefit(context, l10n.goProBenefitOneTime),
            _benefit(context, l10n.goProBenefitSupports),
            const SizedBox(height: 24),
            if (isPro)
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 18,
                ),
                decoration: BoxDecoration(
                  color: context.colors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: context.colors.green.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.verified, color: context.colors.green, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l10n.goProOwned,
                        style: TextStyle(
                          fontFamily: AppFonts.ui,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: context.colors.textPrimary,
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
                  backgroundColor: context.colors.cyan,
                  foregroundColor: context.colors.onAccent,
                  minimumSize: const Size.fromHeight(52),
                ),
                child: Text(
                  product == null ? l10n.goPro : l10n.upgradeFor(product.price),
                  style: const TextStyle(
                    fontFamily: AppFonts.display,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(onPressed: restore, child: Text(l10n.restorePurchase)),
              const SizedBox(height: 8),
              Text(
                product == null
                    ? l10n.oneTimeUnavailable
                    : l10n.oneTimeRestores,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppFonts.ui,
                  fontSize: 11,
                  color: context.colors.textFaint,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _benefit(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.check_circle, color: context.colors.green, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontFamily: AppFonts.ui,
              fontSize: 13.5,
              height: 1.4,
              color: context.colors.textSecondary,
            ),
          ),
        ),
      ],
    ),
  );
}
