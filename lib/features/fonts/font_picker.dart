import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/sheet_body.dart';
import '../../l10n/app_localizations.dart';
import 'custom_fonts.dart';
import 'device_fonts.dart';

/// What the font picker hands back: the family chosen, and whether it was
/// imported just now - the editor says so, since an import is a lasting change
/// to the app and not only to this layer.
typedef FontPick = ({String family, bool imported});

/// The font control in the Text and Bubble panels: the current family, drawn
/// in itself, that opens [showFontPicker].
///
/// One row where there used to be a horizontal strip of chips. A strip works
/// for five fonts; it stopped working once the bundled set tripled and the
/// device's own fonts joined it, because the only way to find one was to
/// scroll sideways past every other.
class FontField extends StatelessWidget {
  const FontField({super.key, required this.family, required this.onTap});

  final String family;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final name = AppFonts.nameOf(family);
    return Semantics(
      button: true,
      // Comma-separated like the colour swatches: the control and its value
      // stay two facts, so neither has to agree with the other.
      label: '${l10n.font}, $name',
      excludeSemantics: true,
      child: Material(
        color: context.colors.inputField,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: context.colors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
              child: Row(
                children: [
                  Icon(
                    Icons.text_fields,
                    size: 18,
                    color: context.colors.textMuted,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: family,
                        fontSize: 18,
                        // The weight the canvas draws it at, so the field
                        // previews the caption rather than the font file.
                        fontWeight: FontWeight.w700,
                        color: context.colors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.unfold_more,
                    size: 20,
                    color: context.colors.textMuted,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Opens the font picker with [current] marked. Null when dismissed.
Future<FontPick?> showFontPicker(
  BuildContext context, {
  required String current,
  required Color accent,
}) {
  return showModalBottomSheet<FontPick>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.colors.panel,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => FontPickerSheet(current: current, accent: accent),
  );
}

/// Every font a caption can use - bundled, imported, and the device's own -
/// with a search field over all three.
///
/// Not a [SheetBody]: that builds its children eagerly, and here building a
/// row is what loads a device font into the engine, where it stays for the
/// life of the process. The list is lazy so that only the fonts someone
/// actually scrolls to are ever loaded.
class FontPickerSheet extends ConsumerStatefulWidget {
  const FontPickerSheet({
    super.key,
    required this.current,
    required this.accent,
  });

  final String current;
  final Color accent;

  @override
  ConsumerState<FontPickerSheet> createState() => _FontPickerSheetState();
}

sealed class _Entry {
  const _Entry();
}

class _Header extends _Entry {
  const _Header(this.text);
  final String text;
}

class _Font extends _Entry {
  const _Font(this.family, {this.device = false});
  final String family;
  final bool device;
}

class _Searching extends _Entry {
  const _Searching();
}

class _NoMatch extends _Entry {
  const _NoMatch();
}

class _Import extends _Entry {
  const _Import();
}

class _FontPickerSheetState extends ConsumerState<FontPickerSheet> {
  final _search = TextEditingController();
  String _query = '';
  bool _importing = false;

  /// What search and de-duplication compare: case- and space-insensitive, so
  /// "luckiestguy" finds "Luckiest Guy" and a device "Space Grotesk" is the
  /// bundled one's twin.
  static String _fold(String s) => s.toLowerCase().replaceAll(' ', '');

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _import() async {
    if (_importing) return;
    setState(() => _importing = true);
    final family = await ref.read(customFontsProvider.notifier).importFont();
    if (!mounted) return;
    if (family == null) {
      setState(() => _importing = false);
      return;
    }
    Navigator.of(context).pop<FontPick>((family: family, imported: true));
  }

  List<_Entry> _entries(AppLocalizations l10n) {
    final imported =
        ref.watch(customFontsProvider).asData?.value ?? const <CustomFont>[];
    final device = ref.watch(deviceFontFamiliesProvider);
    // A name is listed once, in the first section that has it, whether or not
    // it matches the search - the bundled Bangers always wins over a device
    // file of the same name, searched for or not.
    final seen = <String>{};
    List<_Entry> section(String title, Iterable<_Font> fonts) {
      final rows = <_Entry>[
        for (final f in fonts)
          if (seen.add(_fold(AppFonts.nameOf(f.family))) &&
              (_query.isEmpty ||
                  _fold(AppFonts.nameOf(f.family)).contains(_query) ||
                  _fold(f.family).contains(_query)))
            f,
      ];
      return rows.isEmpty ? const [] : [_Header(title), ...rows];
    }

    final entries = <_Entry>[
      ...section(l10n.fontsInApp, AppFonts.bundledFonts.map(_Font.new)),
      ...section(l10n.fontsImported, imported.map((c) => _Font(c.family))),
      ...switch (device) {
        AsyncData(:final value) => section(l10n.fontsOnDevice, [
          for (final f in value) _Font(f.family, device: true),
        ]),
        AsyncError() => const <_Entry>[],
        _ => [_Header(l10n.fontsOnDevice), const _Searching()],
      },
    ];
    if (!entries.any((e) => e is _Font || e is _Searching)) {
      entries.add(const _NoMatch());
    }
    // Last, and kept while searching: someone who typed a name and found
    // nothing is exactly who is about to bring their own file.
    entries.add(const _Import());
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final media = MediaQuery.of(context);
    final entries = _entries(l10n);
    // Three quarters of the screen, less whatever the keyboard takes once the
    // search field has focus, so the field and the first results stay above
    // it rather than the sheet sliding up under the status bar.
    final height = math.max(
      0.0,
      math.min(
        media.size.height * 0.75,
        media.size.height * SheetBody.maxHeightFraction -
            media.viewInsets.bottom,
      ),
    );
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SizedBox(
        height: height,
        child: SafeArea(
          top: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 14),
              const SheetGrabHandle(),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  l10n.font,
                  style: TextStyle(
                    fontFamily: AppFonts.display,
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                    color: context.colors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _searchField(l10n),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: ListView.builder(
                  key: const ValueKey('font-list'),
                  padding: const EdgeInsets.only(bottom: 12),
                  itemCount: entries.length,
                  itemBuilder: (context, i) => _row(entries[i], l10n),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _searchField(AppLocalizations l10n) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: context.colors.border),
    );
    return TextField(
      key: const ValueKey('font-search'),
      controller: _search,
      textInputAction: TextInputAction.search,
      onChanged: (v) => setState(() => _query = _fold(v.trim())),
      style: TextStyle(
        fontFamily: AppFonts.ui,
        color: context.colors.textPrimary,
      ),
      decoration: InputDecoration(
        hintText: l10n.searchFonts,
        hintStyle: TextStyle(color: context.colors.textMuted),
        prefixIcon: Icon(Icons.search, color: context.colors.textMuted),
        suffixIcon: _query.isEmpty
            ? null
            : IconButton(
                tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
                icon: Icon(Icons.close, color: context.colors.textMuted),
                onPressed: () => setState(() {
                  _search.clear();
                  _query = '';
                }),
              ),
        isDense: true,
        filled: true,
        fillColor: context.colors.inputField,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 13,
          vertical: 11,
        ),
        border: border,
        enabledBorder: border,
      ),
    );
  }

  Widget _row(_Entry entry, AppLocalizations l10n) => switch (entry) {
    _Header(:final text) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
      child: Semantics(
        header: true,
        child: Text(
          text,
          style: TextStyle(
            fontFamily: AppFonts.ui,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
            color: context.colors.textMuted,
          ),
        ),
      ),
    ),
    _Font(:final family, :final device) => _FontRow(
      key: ValueKey('font-option-$family'),
      family: family,
      device: device,
      selected: family == widget.current,
      accent: widget.accent,
      onTap: () => Navigator.of(
        context,
      ).pop<FontPick>((family: family, imported: false)),
    ),
    _Searching() => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: context.colors.textMuted,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l10n.fontsSearchingDevice,
              style: TextStyle(
                fontFamily: AppFonts.ui,
                fontSize: 12.5,
                color: context.colors.textMuted,
              ),
            ),
          ),
        ],
      ),
    ),
    _NoMatch() => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Text(
        l10n.noFontsMatch,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: AppFonts.ui,
          fontSize: 13,
          color: context.colors.textMuted,
        ),
      ),
    ),
    _Import() => Padding(
      padding: const EdgeInsets.only(top: 8),
      child: InkWell(
        key: const ValueKey('font-import'),
        onTap: _importing ? null : _import,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.add, size: 20, color: context.colors.textSecondary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.importFontFile,
                        style: TextStyle(
                          fontFamily: AppFonts.ui,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: context.colors.textPrimary,
                        ),
                      ),
                      Text(
                        l10n.importFontFileSub,
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
          ),
        ),
      ),
    ),
  };
}

/// One font, its name drawn in itself.
class _FontRow extends ConsumerStatefulWidget {
  const _FontRow({
    super.key,
    required this.family,
    required this.device,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final String family;
  final bool device;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  ConsumerState<_FontRow> createState() => _FontRowState();
}

class _FontRowState extends ConsumerState<_FontRow> {
  @override
  void initState() {
    super.initState();
    // A device font is loaded the first time its row is built, i.e. scrolled
    // to. The name re-lays itself out in its own face when it lands - a font
    // load is announced to every paragraph - so nothing here waits for it.
    if (widget.device) {
      unawaited(ref.read(deviceFontsProvider).ensure(widget.family));
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = AppFonts.nameOf(widget.family);
    return Semantics(
      button: true,
      selected: widget.selected,
      label: name,
      excludeSemantics: true,
      child: Material(
        color: widget.selected
            ? widget.accent.withValues(alpha: 0.14)
            : Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: widget.family,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: context.colors.textPrimary,
                      ),
                    ),
                  ),
                  if (widget.selected) ...[
                    const SizedBox(width: 10),
                    Icon(Icons.check_rounded, size: 20, color: widget.accent),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
