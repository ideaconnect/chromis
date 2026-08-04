import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_typography.dart';
import '../../l10n/app_localizations.dart';
import 'ads_service.dart';

/// "Ad privacy choices" - reopens the UMP consent form so a user can change the
/// answer they gave on first launch.
///
/// Google requires this entry point to be permanently available wherever
/// consent applies, and the app's own published policy promises it. Before
/// this, `showPrivacyOptionsForm` was called from nowhere: the form appeared
/// exactly once, on first launch, and the decision was permanent.
///
/// Renders nothing at all outside the EEA/UK, where
/// [PrivacyOptionsRequirementStatus.required] is never reported - a dead row
/// that opens an empty form is worse than no row.
class AdPrivacyOptionsCard extends ConsumerStatefulWidget {
  const AdPrivacyOptionsCard({super.key});

  @override
  ConsumerState<AdPrivacyOptionsCard> createState() =>
      _AdPrivacyOptionsCardState();
}

class _AdPrivacyOptionsCardState extends ConsumerState<AdPrivacyOptionsCard> {
  bool _required = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    try {
      final status = await ConsentInformation.instance
          .getPrivacyOptionsRequirementStatus();
      if (!mounted) return;
      setState(() {
        _required = status == PrivacyOptionsRequirementStatus.required;
      });
    } catch (_) {
      // Consent info not gathered yet (offline first launch, say). Staying
      // hidden is the safe answer - the row reappears next launch.
    }
  }

  Future<void> _open() async {
    if (_busy) return;
    setState(() => _busy = true);
    // Through [AdsService], never `ConsentForm` directly. Calling UMP from here
    // showed the right form and then told nobody: `canRequestAds` kept the
    // value it read at launch, so withdrawing consent on this screen left the
    // Home banner on screen and the export gate still offering an ad. Going
    // through the service re-reads the answer and publishes it, and the banner
    // is listening. It never throws - it reports through [onError] instead.
    await ref
        .read(adsServiceProvider)
        .requestConsent(
          genericReason: AppLocalizations.of(context).pleaseTryAgain,
          onError: (message) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  AppLocalizations.of(context).adSettingsFailed(message),
                ),
              ),
            );
          },
        );
    if (mounted) setState(() => _busy = false);
    // The answer can also change whether this entry point is required at all.
    await _check();
  }

  @override
  Widget build(BuildContext context) {
    if (!_required) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: _busy ? null : _open,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Icon(
                  Icons.privacy_tip_outlined,
                  size: 20,
                  color: context.colors.textSecondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.of(context).adPrivacyChoices,
                        style: TextStyle(
                          fontFamily: AppFonts.ui,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: context.colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        AppLocalizations.of(context).adPrivacyChoicesSub,
                        style: TextStyle(
                          fontFamily: AppFonts.ui,
                          fontSize: 11.5,
                          color: context.colors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_busy)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(
                    Icons.chevron_right,
                    color: context.colors.textMuted,
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
