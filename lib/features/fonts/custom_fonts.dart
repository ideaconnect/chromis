import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/theme/app_typography.dart';

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
class CustomFontStore {
  Future<Directory> _dir() async {
    final base = await getApplicationDocumentsDirectory();
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
  Future<List<CustomFont>> loadAndRegister() async {
    final dir = await _dir();
    final ok = <CustomFont>[];
    for (final c in await _read()) {
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
    final family = _uniqueFamily(
      _familyFromName(picked.name),
      existing.map((c) => c.family).toSet(),
    );
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

  static String _uniqueFamily(String base, Set<String> taken) {
    if (!taken.contains(base)) return base;
    var n = 2;
    while (taken.contains('$base $n')) {
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
  Future<List<CustomFont>> build() =>
      ref.read(customFontStoreProvider).loadAndRegister();

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

/// Family names available to the Text/Bubble pickers: bundled first, then the
/// user's imported fonts.
final availableFontsProvider = Provider<List<String>>((ref) {
  final custom = ref.watch(customFontsProvider).asData?.value ?? const [];
  return [...AppFonts.bundledFonts, for (final c in custom) c.family];
});
