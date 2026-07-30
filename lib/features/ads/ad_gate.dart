import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/sheet_body.dart';
import '../go_pro/iap.dart';
import 'ads_service.dart';

/// The single prompt shown whenever a free user has to watch an ad to do
/// something, and the whole flow behind it.
///
/// Every ad gate in the app goes through [AdGate.run]. That is the point: the
/// two gates that existed before this were written twice, and had drifted into a
/// polished bottom sheet on one side and a stock [AlertDialog] on the other,
/// where "Go Pro" was a low-emphasis text button sitting next to "Cancel". The
/// paid upgrade is the only way out of ads, so it cannot be the option that
/// happens to look like an afterthought - and a gate added later must not be
/// able to forget it at all.
///
/// Pro users never see any of this: [AdGate.run] short-circuits before building
/// anything.
enum AdGateChoice { watch, goPro }

/// What actually happened at the gate.
///
/// A bare bool is not enough, and the first version of this learned that the
/// hard way: three different endings collapse to "may not proceed", and the AI
/// gate's "watch the full ad" nag then fired on all of them - including over the
/// Go Pro screen the user had just chosen to open, telling someone who was in
/// the middle of buying their way out of ads to consider buying their way out of
/// ads.
enum AdGateOutcome {
  /// Pro, or the ad was watched through to its reward. Proceed.
  allowed,

  /// The sheet was dismissed without choosing. A decision, not a failure.
  dismissed,

  /// They chose the upgrade; the Go Pro screen has been pushed.
  wentToPro,

  /// They chose to watch, but the ad ended without earning the reward. The only
  /// ending worth explaining to the user.
  notRewarded,

  /// Ads are switched off by the user's own consent choice, so there is no ad
  /// to watch - and they left without either allowing ads or upgrading.
  ///
  /// Separate from [dismissed] because the sheet has already explained the
  /// situation and offered both ways out: a caller must not follow it with a
  /// "watch the full ad" nag, which is advice they cannot act on.
  adsDeclined;

  bool get allows => this == AdGateOutcome.allowed;
}

abstract final class AdGate {
  AdGate._();

  /// Asks the user to watch an ad or upgrade, then does what they chose.
  ///
  /// Check [AdGateOutcome.allows] to decide whether to go ahead; the specific
  /// outcome is there so a caller can tell a refusal from a failure and say
  /// something only when there is something to say. Going to Go Pro pushes that
  /// screen from here, so callers just stop.
  ///
  /// [title], [message] and [watchLabel] are per-action so the prompt can say
  /// what is actually about to happen; everything else is fixed so the decision
  /// looks the same wherever it is asked.
  static Future<AdGateOutcome> run(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required String message,
    required String watchLabel,
  }) async {
    if (ref.read(isProProvider)) return AdGateOutcome.allowed;

    final ads = ref.read(adsServiceProvider);
    // The ad is what pays for this action, so someone who turned ads off is
    // asked again here - once, on the way in - rather than quietly getting it
    // for free. Only when we already KNOW ads are blocked: `canRequestAds`
    // starts true and answers synchronously, so the ordinary path adds nothing
    // to wait for.
    if (!ads.canRequestAds) await ads.requestConsent();
    if (!context.mounted) return AdGateOutcome.dismissed;

    final choice = await showModalBottomSheet<AdGateChoice>(
      context: context,
      // So the sheet may use the height it needs; SheetBody caps and scrolls it.
      isScrollControlled: true,
      backgroundColor: AppColors.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) =>
          AdGateSheet(title: title, message: message, watchLabel: watchLabel),
    );
    if (!context.mounted || choice == null) {
      // Leaving a sheet that had nothing to offer is not the same as declining
      // an ad that was on the table.
      return ads.canRequestAds
          ? AdGateOutcome.dismissed
          : AdGateOutcome.adsDeclined;
    }
    if (choice == AdGateChoice.goPro) {
      unawaited(context.pushNamed(Routes.goPro));
      return AdGateOutcome.wentToPro;
    }
    return await ref.read(adsServiceProvider).showRewarded()
        ? AdGateOutcome.allowed
        : AdGateOutcome.notRewarded;
  }
}

/// The gate's UI. Public only so a widget test can pump it directly.
class AdGateSheet extends ConsumerStatefulWidget {
  const AdGateSheet({
    super.key,
    required this.title,
    required this.message,
    required this.watchLabel,
  });

  final String title;
  final String message;
  final String watchLabel;

  @override
  ConsumerState<AdGateSheet> createState() => _AdGateSheetState();
}

class _AdGateSheetState extends ConsumerState<AdGateSheet> {
  bool _askingConsent = false;

  /// Whether ads are off because of the user's consent choice, so there is no
  /// ad to offer. Read live rather than passed in: answering the form from
  /// inside this sheet has to flip it without reopening anything.
  bool get _blocked => !ref.read(adsServiceProvider).canRequestAds;

  Future<void> _reviewConsent() async {
    if (_askingConsent) return;
    setState(() => _askingConsent = true);
    try {
      await ref.read(adsServiceProvider).requestConsent();
    } finally {
      // The form may have been answered either way; rebuilding is what turns
      // the watch button back on, or leaves the warning standing.
      if (mounted) setState(() => _askingConsent = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final blocked = _blocked;
    return SheetBody(
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 22),
      children: [
        const SizedBox(height: 4),
        Icon(
          blocked ? Icons.block_outlined : Icons.play_circle_outline,
          color: blocked ? AppColors.amber : AppColors.cyan,
          size: 36,
        ),
        const SizedBox(height: 12),
        Text(
          widget.title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: AppFonts.display,
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          widget.message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: AppFonts.ui,
            fontSize: 13,
            height: 1.4,
            color: AppColors.textMuted,
          ),
        ),
        if (blocked) ...[
          const SizedBox(height: 16),
          _ConsentWarning(busy: _askingConsent, onReview: _reviewConsent),
        ],
        const SizedBox(height: 22),
        FilledButton.icon(
          key: const ValueKey('ad-gate-watch'),
          // Greyed out, not hidden: the action still costs an ad, and the
          // warning directly above says why there is none to watch.
          onPressed: blocked
              ? null
              : () => Navigator.pop(context, AdGateChoice.watch),
          icon: const Icon(Icons.play_arrow_rounded),
          label: Text(widget.watchLabel),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.cyan,
            foregroundColor: AppColors.cutoutInk,
            disabledBackgroundColor: AppColors.cyan.withValues(alpha: 0.22),
            disabledForegroundColor: AppColors.textFaint,
            minimumSize: const Size.fromHeight(50),
            textStyle: const TextStyle(
              fontFamily: AppFonts.display,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ),
        const SizedBox(height: 10),
        // An outlined button of the same height, not a bare text link. This is
        // the only way to stop seeing ads at all, so it gets equal weight to
        // "watch" rather than reading as a footnote under it.
        OutlinedButton.icon(
          key: const ValueKey('ad-gate-go-pro'),
          onPressed: () => Navigator.pop(context, AdGateChoice.goPro),
          icon: const Icon(Icons.workspace_premium_outlined, size: 19),
          label: const Text('Go Pro - remove ads'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.gold,
            minimumSize: const Size.fromHeight(50),
            side: const BorderSide(color: AppColors.gold, width: 1.4),
            textStyle: const TextStyle(
              fontFamily: AppFonts.display,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'One-time purchase. No subscription.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppFonts.ui,
            fontSize: 11.5,
            color: AppColors.textFaint,
          ),
        ),
      ],
    );
  }
}

/// Shown in place of a watchable ad when the user's consent choice has switched
/// ads off entirely.
///
/// Says what is true and gives both ways forward, because the state is one the
/// user chose and can unchoose: allow ads and this action stays free, or buy
/// Pro and it never needs an ad again. It deliberately does not argue - the
/// consent form itself lets them decline again, and this reappears if they do.
class _ConsentWarning extends StatelessWidget {
  const _ConsentWarning({required this.busy, required this.onReview});

  final bool busy;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('ad-gate-consent-warning'),
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      decoration: BoxDecoration(
        color: AppColors.amber.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.amber.withValues(alpha: 0.45)),
      ),
      child: Column(
        children: [
          // Deliberately not export-specific: the AI tools use this same gate.
          const Text(
            "You've chosen not to allow ads, so there is no ad to watch - and "
            'ads are what keep Chromis free.\n\n'
            'Allow ads to carry on for free, or go Pro to use everything with '
            'no ads at all.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppFonts.ui,
              fontSize: 12.5,
              height: 1.45,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const ValueKey('ad-gate-consent'),
            onPressed: busy ? null : onReview,
            icon: busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.cutoutInk,
                    ),
                  )
                : const Icon(Icons.privacy_tip_outlined, size: 18),
            label: const Text('Review ad consent'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.amber,
              foregroundColor: AppColors.cutoutInk,
              minimumSize: const Size.fromHeight(44),
              textStyle: const TextStyle(
                fontFamily: AppFonts.display,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
