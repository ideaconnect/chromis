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

abstract final class AdGate {
  AdGate._();

  /// Asks the user to watch an ad or upgrade, then does what they chose.
  ///
  /// Returns **true** only when the caller may proceed: the user is Pro, or the
  /// ad was watched. Returns false when they dismissed the sheet or went to Go
  /// Pro (that screen is pushed here, so callers just stop).
  ///
  /// [title], [message] and [watchLabel] are per-action so the prompt can say
  /// what is actually about to happen; everything else is fixed so the decision
  /// looks the same wherever it is asked.
  static Future<bool> run(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required String message,
    required String watchLabel,
  }) async {
    if (ref.read(isProProvider)) return true;

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
    if (!context.mounted || choice == null) return false;
    if (choice == AdGateChoice.goPro) {
      unawaited(context.pushNamed(Routes.goPro));
      return false;
    }
    return ref.read(adsServiceProvider).showRewarded();
  }
}

/// The gate's UI. Public only so a widget test can pump it directly.
class AdGateSheet extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return SheetBody(
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 22),
      children: [
        const SizedBox(height: 4),
        const Icon(Icons.play_circle_outline, color: AppColors.cyan, size: 36),
        const SizedBox(height: 12),
        Text(
          title,
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
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: AppFonts.ui,
            fontSize: 13,
            height: 1.4,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 22),
        FilledButton.icon(
          key: const ValueKey('ad-gate-watch'),
          onPressed: () => Navigator.pop(context, AdGateChoice.watch),
          icon: const Icon(Icons.play_arrow_rounded),
          label: Text(watchLabel),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.cyan,
            foregroundColor: AppColors.cutoutInk,
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
