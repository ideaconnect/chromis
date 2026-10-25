import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/theme/app_typography.dart';
import 'device_fonts.dart';

/// A user-imported font: its registered [family] name and the [fileName] of the
/// copied .ttf/.otf inside the app's fonts directory.
class CustomFont {
  const CustomFont(this.family, this.fileName);
  final String family;
  final String fileName;
}

/// Stores, registers and imports user font files. Imported fonts live under
/// `<app documents>/fonts/`, catalogued in `fonts.json`; each is registered at
/// runtime with [FontLoader] so `TextStyle(fontFamily: family)` renders it.
/// Pass [baseDir] in tests to use a temp directory.
class CustomFontStore {
  CustomFontStore({Directory? baseDir}) : _baseOverride = baseDir;

  final Directory? _baseOverride;

  Future<Directory> _dir() async {
    final base = _baseOverride ?? await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/fonts');
    if (!dir.existsSync()) await dir.create(recursive: true);
    return dir;
  }

  Future<File> _manifest() async => File('${(await _dir()).path}/fonts.json');

  Future<List<CustomFont>> _read() async {
    try {
      final f = await _manifest();
      if (!f.existsSync()) return const [];
      final list = jsonDecode(await f.readAsString()) as List<dynamic>;
      return [
        for (final m in list.cast<Map<String, dynamic>>())
          CustomFont(m['family'] as String, m['file'] as String),
      ];
    } catch (_) {
      return const [];
    }
  }

  Future<void> _write(List<CustomFont> fonts) async {
    final f = await _manifest();
    await f.writeAsString(
      jsonEncode([
        for (final c in fonts) {'family': c.family, 'file': c.fileName},
      ]),
    );
  }

  static Future<void> _register(String family, Uint8List bytes) async {
    // Claimed before it loads, so a device font of the same name can never be
    // registered into this family as a second face.
    DeviceFonts.instance.reserve(family);
    final loader = FontLoader(family)
      ..addFont(
        Future.value(
          ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.lengthInBytes),
        ),
      );
    await loader.load();
  }

  /// Loads every persisted font and registers it with the engine, returning the
  /// catalogue (best-effort - a missing/corrupt file is skipped).
  ///
  /// Every name is reserved against the device's fonts before any file is
  /// read - see [DeviceFonts.holdUntilImportsKnown] for the race that closes.
  Future<List<CustomFont>> loadAndRegister() async {
    final dir = await _dir();
    final catalogue = await _read();
    final fonts = _renameAppOwned(catalogue);
    if (!identical(fonts, catalogue)) {
      try {
        await _write(fonts);
      } catch (_) {
        // Still registered under the new names this session; the rename is
        // simply made again on the next launch.
      }
    }
    for (final c in fonts) {
      DeviceFonts.instance.reserve(c.family);
    }
    final ok = <CustomFont>[];
    for (final c in fonts) {
      try {
        final file = File('${dir.path}/${c.fileName}');
        if (!file.existsSync()) continue;
        await _register(c.family, await file.readAsBytes());
        ok.add(c);
      } catch (_) {}
    }
    return ok;
  }

  /// Prompts for a .ttf/.otf, copies it in, registers + catalogues it. Returns
  /// the new font, or null if cancelled / unreadable.
  Future<CustomFont?> import() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['ttf', 'otf'],
      withData: true,
    );
    if (res == null || res.files.isEmpty) return null;
    final picked = res.files.first;
    final bytes =
        picked.bytes ??
        (picked.path != null ? await File(picked.path!).readAsBytes() : null);
    if (bytes == null) return null;
    final existing = await _read();
    final ext = (picked.extension ?? 'ttf').toLowerCase();
    // Unique against every name the picker shows, not only the other imports:
    // registered under a device family's name the file would merge into that
    // family, and under a bundled one's label it would be a second row
    // reading the same as the first.
    final device = await DeviceFonts.instance.families();
    final family = _uniqueFamily(_familyFromName(picked.name), {
      for (final c in existing) c.family.toLowerCase(),
      for (final d in device) d.family.toLowerCase(),
      ..._appOwned,
    });
    final fileName = '$family.$ext';
    await File('${(await _dir()).path}/$fileName').writeAsBytes(bytes);
    await _register(family, bytes);
    final font = CustomFont(family, fileName);
    await _write([...existing, font]);
    return font;
  }

  static String _familyFromName(String name) {
    final s = name
        .replaceAll(RegExp(r'\.(ttf|otf)$', caseSensitive: false), '')
        .replaceAll(RegExp('[^A-Za-z0-9 ]'), ' ')
        .trim();
    return s.isEmpty ? 'Custom font' : s;
  }

  /// The names the app draws with itself, lower-cased: every bundled caption
  /// family by key and by written name, and the UI face - an import named
  /// "Manrope" would otherwise become a second face of every label in the app.
  static Set<String> get _appOwned => {
    for (final b in [...AppFonts.bundledFonts, AppFonts.ui]) ...[
      b.toLowerCase(),
      AppFonts.nameOf(b).toLowerCase(),
    ],
  };

  /// [fonts] with every family that collides with an app-owned name
  /// renumbered - "Lobster" becomes "Lobster 2" - or [fonts] itself when
  /// none does.
  ///
  /// Imports made before the bundled set grew were only checked against each
  /// other, so a "Lobster.ttf" imported then is family "Lobster" - and
  /// registered under that name now it would join the bundled Lobster as a
  /// second face, with the engine choosing between the two files by weight.
  /// The file stays, under its new name. A project that named the old family
  /// draws the bundled face of that name instead, which for a file called
  /// Lobster.ttf is almost certainly the same typeface.
  static List<CustomFont> _renameAppOwned(List<CustomFont> fonts) {
    final owned = _appOwned;
    if (!fonts.any((c) => owned.contains(c.family.toLowerCase()))) {
      return fonts;
    }
    final taken = {...owned, for (final c in fonts) c.family.toLowerCase()};
    return [
      for (final c in fonts)
        if (owned.contains(c.family.toLowerCase()))
          CustomFont(_claim(c.family, taken), c.fileName)
        else
          c,
    ];
  }

  /// [_uniqueFamily], with the answer added to [taken].
  static String _claim(String base, Set<String> taken) {
    final family = _uniqueFamily(base, taken);
    taken.add(family.toLowerCase());
    return family;
  }

  /// [base], numbered if need be so it is not in [taken] (lower-cased).
  static String _uniqueFamily(String base, Set<String> taken) {
    if (!taken.contains(base.toLowerCase())) return base;
    var n = 2;
    while (taken.contains('$base $n'.toLowerCase())) {
      n++;
    }
    return '$base $n';
  }
}

final customFontStoreProvider = Provider<CustomFontStore>(
  (ref) => CustomFontStore(),
);

/// The user's imported fonts. Loads + registers them on first read (watched at
/// app start so they render immediately); [importFont] adds a new one.
class CustomFontsController extends AsyncNotifier<List<CustomFont>> {
  @override
  Future<List<CustomFont>> build() {
    final loaded = ref.read(customFontStoreProvider).loadAndRegister();
    // The device's fonts wait for these names - see
    // DeviceFonts.holdUntilImportsKnown.
    DeviceFonts.instance.holdUntilImportsKnown(loaded);
    return loaded;
  }

  /// Imports a font file; returns its new family name, or null if cancelled.
  Future<String?> importFont() async {
    final font = await ref.read(customFontStoreProvider).import();
    if (font == null) return null;
    state = AsyncData([...(state.asData?.value ?? const []), font]);
    return font.family;
  }
}

final customFontsProvider =
    AsyncNotifierProvider<CustomFontsController, List<CustomFont>>(
      CustomFontsController.new,
    );
