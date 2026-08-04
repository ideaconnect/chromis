import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/responsive_center.dart';
import '../../l10n/app_localizations.dart';
import '../ads/consent_options.dart';
import 'about_data.dart';

/// In-app privacy summary. Mirrors `docs/legal/privacy-policy.md`; the full
/// hosted policy lives at [AboutInfo.privacyUrl] (shown here, selectable).
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _topBar(context),
            Expanded(
              // Capped so the measure stays readable: uncapped, every row
              // ran the full width of a tablet (and of a phone in landscape),
              // stranding a label at one edge and its value at the other.
              child: ResponsiveCenter(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: context.colors.green.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: context.colors.green.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.verified_user_outlined,
                            size: 22,
                            color: context.colors.green,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              l10n.privacyBanner,
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
                    ),
                    const SizedBox(height: 20),
                    for (final line in privacyHighlights(l10n))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.check_circle,
                              size: 18,
                              color: context.colors.green,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                line,
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
                      ),
                    const SizedBox(height: 12),
                    // Only rendered where UMP says consent applies (the EEA/UK).
                    // Without it, a user who answered the consent form once had
                    // no way to change their mind - which the published policy
                    // says they can.
                    const AdPrivacyOptionsCard(),
                    _LinkCard(
                      icon: Icons.link,
                      label: l10n.fullPrivacyPolicy,
                      value: AboutInfo.privacyUrl,
                    ),
                    const SizedBox(height: 10),
                    _LinkCard(
                      icon: Icons.mail_outline,
                      label: l10n.questions,
                      value: AboutInfo.contactEmail,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 10, 6, 6),
      child: Row(
        children: [
          IconButton(
            tooltip: AppLocalizations.of(context).back,
            onPressed: () => context.pop(),
            icon: Icon(
              Icons.chevron_left,
              size: 26,
              color: context.colors.textSecondary,
            ),
          ),
          Expanded(
            child: Text(
              AppLocalizations.of(context).privacyTitle,
              style: TextStyle(
                fontFamily: AppFonts.display,
                fontWeight: FontWeight.w600,
                fontSize: 17,
                color: context.colors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 44),
        ],
      ),
    );
  }
}

class _LinkCard extends StatelessWidget {
  const _LinkCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colors.borderFaint),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: context.colors.textMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: AppFonts.ui,
                    fontSize: 11.5,
                    color: context.colors.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                SelectableText(
                  value,
                  style: TextStyle(
                    fontFamily: AppFonts.ui,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: context.colors.violetLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
