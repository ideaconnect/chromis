import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_logo.dart';
import '../../core/widgets/sheet_body.dart';
import '../../l10n/app_localizations.dart';
import '../go_pro/iap.dart';
import 'about_data.dart';

/// Opens the About / settings sheet from the Home avatar: app identity plus
/// links to the privacy summary and open-source licenses.
Future<void> showAboutSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    // So the sheet may use the height it needs; SheetBody caps and scrolls it.
    isScrollControlled: true,
    backgroundColor: context.colors.panel,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => _AboutSheet(parentContext: context),
  );
}

class _AboutSheet extends ConsumerWidget {
  const _AboutSheet({required this.parentContext});

  /// The screen's context, used to navigate after the sheet closes.
  final BuildContext parentContext;

  void _go(BuildContext sheetContext, String route) {
    Navigator.of(sheetContext).pop();
    parentContext.pushNamed(route);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return SheetBody(
      children: [
        const SizedBox(height: 2),
        Row(
          children: [
            const AppLogo(size: 46, radius: 14),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AboutInfo.appName,
                    style: TextStyle(
                      fontFamily: AppFonts.display,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      color: context.colors.textPrimary,
                    ),
                  ),
                  Text(
                    'v${AboutInfo.appVersion} · ${AboutInfo.publisher}',
                    style: TextStyle(
                      fontFamily: AppFonts.ui,
                      fontSize: 11.5,
                      color: context.colors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (!ref.watch(isProProvider)) ...[
          _AboutRow(
            icon: Icons.workspace_premium_outlined,
            label: l10n.goProRemoveAds,
            sub: l10n.goProRowSub,
            onTap: () => _go(context, Routes.goPro),
          ),
          const SizedBox(height: 10),
        ],
        _AboutRow(
          icon: Icons.verified_user_outlined,
          label: l10n.privacyTitle,
          sub: l10n.privacyRowSub,
          onTap: () => _go(context, Routes.privacy),
        ),
        const SizedBox(height: 10),
        _AboutRow(
          icon: Icons.article_outlined,
          label: l10n.openSourceLicenses,
          sub: l10n.licensesRowSub,
          onTap: () => _go(context, Routes.licenses),
        ),
      ],
    );
  }
}

class _AboutRow extends StatelessWidget {
  const _AboutRow({
    required this.icon,
    required this.label,
    required this.sub,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String sub;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: context.colors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.colors.borderFaint),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: context.colors.violet.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, size: 19, color: context.colors.violetLight),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontFamily: AppFonts.ui,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: context.colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      sub,
                      style: TextStyle(
                        fontFamily: AppFonts.ui,
                        fontSize: 11.5,
                        color: context.colors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: context.colors.textFaint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
