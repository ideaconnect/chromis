import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

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
class AdPrivacyOptionsCard extends StatefulWidget {
  const AdPrivacyOptionsCard({super.key});

  @override
  State<AdPrivacyOptionsCard> createState() => _AdPrivacyOptionsCardState();
}

class _AdPrivacyOptionsCardState extends State<AdPrivacyOptionsCard> {
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
    try {
      await ConsentForm.showPrivacyOptionsForm((error) {
        if (error != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Couldn't open ad settings: ${error.message}"),
            ),
          );
        }
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Couldn't open ad settings - try again"),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    // The answer may have changed what can be requested; the next launch picks
    // it up, and existing ads are not retroactively affected either way.
    await _check();
  }

  @override
  Widget build(BuildContext context) {
    if (!_required) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: _busy ? null : _open,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                const Icon(
                  Icons.privacy_tip_outlined,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ad privacy choices',
                        style: TextStyle(
                          fontFamily: AppFonts.ui,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Change the consent you gave for personalised ads',
                        style: TextStyle(
                          fontFamily: AppFonts.ui,
                          fontSize: 11.5,
                          color: AppColors.textMuted,
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
                  const Icon(
                    Icons.chevron_right,
                    color: AppColors.textMuted,
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
