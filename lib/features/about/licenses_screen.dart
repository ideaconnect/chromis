import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/responsive_center.dart';
import '../../l10n/app_localizations.dart';
import 'about_data.dart';

/// Curated third-party attributions, grouped by category, with a link to
/// Flutter's full aggregated license page (which also lists every pub package).
class LicensesScreen extends StatelessWidget {
  const LicensesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final categories = licenseCategories();
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _topBar(context, l10n.openSourceLicenses),
            Expanded(
              // Capped so the measure stays readable: uncapped, every row
              // ran the full width of a tablet (and of a phone in landscape),
              // stranding a label at one edge and its value at the other.
              child: ResponsiveCenter(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                  children: [
                    Text(
                      l10n.licensesIntro,
                      style: TextStyle(
                        fontFamily: AppFonts.ui,
                        fontSize: 13,
                        height: 1.45,
                        color: context.colors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 18),
                    for (final category in categories) ...[
                      _SectionHeader(localizedLicenseCategory(l10n, category)),
                      const SizedBox(height: 10),
                      for (final n in licenseNotices.where(
                        (n) => n.category == category,
                      ))
                        _NoticeCard(n),
                      const SizedBox(height: 18),
                    ],
                    OutlinedButton.icon(
                      onPressed: () => showLicensePage(
                        context: context,
                        applicationName: AboutInfo.appName,
                        applicationVersion: AboutInfo.appVersion,
                      ),
                      icon: const Icon(Icons.article_outlined, size: 18),
                      label: Text(l10n.viewFullLicenseTexts),
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
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        fontFamily: AppFonts.ui,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
        color: context.colors.textMuted,
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard(this.notice);

  final LicenseNotice notice;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colors.borderFaint),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notice.name,
                  style: TextStyle(
                    fontFamily: AppFonts.ui,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${localizedLicenseUse(AppLocalizations.of(context), notice.use)}'
                  ' · ${notice.by}',
                  style: TextStyle(
                    fontFamily: AppFonts.ui,
                    fontSize: 11.5,
                    color: context.colors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: context.colors.violet.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              notice.license,
              style: TextStyle(
                fontFamily: AppFonts.ui,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: context.colors.violetLight,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _topBar(BuildContext context, String title) {
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
            title,
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
