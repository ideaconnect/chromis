import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';

/// Prompts for a name (e.g. renaming a project). Returns the trimmed
/// name, or null if cancelled / left blank - blank input never renames, so
/// callers keep the old name (mirrors the pack rename guard).
///
/// [hint] and [confirmLabel] fall back to the localized "Name" / "Save", so a
/// caller with nothing special to say does not have to reach for l10n itself.
Future<String?> promptName(
  BuildContext context, {
  required String title,
  String initial = '',
  String? hint,
  String? confirmLabel,
}) {
  final l10n = AppLocalizations.of(context);
  return showDialog<String>(
    context: context,
    builder: (ctx) => _NamePromptDialog(
      title: title,
      initial: initial,
      hint: hint ?? l10n.nameHint,
      confirmLabel: confirmLabel ?? l10n.save,
    ),
  ).then((v) {
    final name = v?.trim() ?? '';
    return name.isEmpty ? null : name;
  });
}

/// Owns its [TextEditingController] so it is disposed exactly when the dialog
/// element leaves the tree - disposing an externally-held controller right
/// after `showDialog` returns crashes the dialog's exit animation.
class _NamePromptDialog extends StatefulWidget {
  const _NamePromptDialog({
    required this.title,
    required this.initial,
    required this.hint,
    required this.confirmLabel,
  });

  final String title;
  final String initial;
  final String hint;
  final String confirmLabel;

  @override
  State<_NamePromptDialog> createState() => _NamePromptDialogState();
}

class _NamePromptDialogState extends State<_NamePromptDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.pop(context, _controller.text.trim());

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: context.colors.panel,
      title: Text(
        widget.title,
        style: TextStyle(
          fontFamily: AppFonts.display,
          color: context.colors.textPrimary,
          fontSize: 17,
        ),
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        style: TextStyle(color: context.colors.textPrimary),
        decoration: InputDecoration(
          filled: true,
          fillColor: context.colors.inputField,
          hintText: widget.hint,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppLocalizations.of(context).cancel),
        ),
        TextButton(onPressed: _submit, child: Text(widget.confirmLabel)),
      ],
    );
  }
}
