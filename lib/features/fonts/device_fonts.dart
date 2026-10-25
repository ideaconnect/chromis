import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/layer.dart';
import '../../core/theme/app_typography.dart';
import 'font_file_info.dart';

/// Where Android keeps the fonts it ships. `/system/fonts` is AOSP's; a
/// Pixel's Google Sans and other OEM faces live under `/product/fonts`, and
/// some builds use `/system_ext/fonts`. All three are world-readable, so no
/// permission and no platform channel is involved.
const kDeviceFontDirectories = [
  '/system/fonts',
  '/product/fonts',
  '/system_ext/fonts',
];

/// Android's own font configuration: `fonts.xml`, and the overlay a Pixel or
/// an OEM adds for the faces it ships under `/product`.
const kDeviceFontConfigs = [
  '/system/etc/fonts.xml',
  '/product/etc/fonts_customization.xml',
];

/// The file names [configs] list under a NAMED family - `<family
/// name="serif">`, the families `Typeface.create("serif")` can reach - as
/// opposed to a `<family lang="und-Hebr">` script fallback. Empty when none
/// of them can be read.
///
/// This is what tells a typeface from a fallback, and nothing in the files
/// themselves does: a Latin check keeps Noto Sans Hebrew, Khmer and Tamil UI,
/// which all carry a plain Latin for mixed text, and their names follow no
/// rule a list could rely on. Since Android 15 the fallbacks moved to a
/// `font_fallback.xml` apps cannot read, so "listed only as a fallback" cannot
/// be asked; "listed by name" can, and it also drops the duplicate
/// `RobotoStatic`, which no named family uses.
Set<String> namedFontFiles(Iterable<String> configs) {
  final family = RegExp(r'<family\b([^>]*)>(.*?)</family>', dotAll: true);
  final font = RegExp(r'<font\b[^>]*>\s*([^<\s]+)');
  final named = RegExp(r'\bname\s*=');
  final files = <String>{};
  for (final path in configs) {
    final String xml;
    try {
      xml = File(path).readAsStringSync();
    } catch (_) {
      continue;
    }
    final body = xml.replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');
    for (final m in family.allMatches(body)) {
      if (!named.hasMatch(m.group(1)!)) continue;
      for (final f in font.allMatches(m.group(2)!)) {
        files.add(f.group(1)!);
      }
    }
  }
  return files;
}

/// The largest font file offered.
///
/// It leaves out the CJK collections (20-30 MB) and the colour emoji font
/// (10 MB+), and that is the point of it: a family shown in the picker is
/// registered with the engine for the life of the process, and on a 2 GB
/// phone a list that could pin a 30 MB font in memory by being scrolled past
/// is a list that gets the editor killed in the background. Their Latin is
/// a plain sans anyway, and their own scripts reach every caption through
/// the engine's fallback whichever family is chosen.
const int kMaxDeviceFontBytes = 6 * 1024 * 1024;

/// One of the device's font families, as the picker offers it.
@immutable
class DeviceFontFamily {
  const DeviceFontFamily(this.family, this.path);

  final String family;

  /// The one face registered for it - see [pickDrawingFace].
  final String path;

  @override
  bool operator ==(Object other) =>
      other is DeviceFontFamily && other.family == family && other.path == path;

  @override
  int get hashCode => Object.hash(family, path);

  @override
  String toString() => 'DeviceFontFamily($family, $path)';
}

/// Of one family's [faces], the one the app will actually draw with.
///
/// Captions and bubbles always draw at w700, so that is the face wanted: the
/// upright face nearest 700, a static face before a variable one (a variable
/// font loaded at runtime draws at its default instance, so only a static
/// face's declared weight is the weight it renders), then the smaller file.
///
/// One face per family, not the whole family: Light, Medium and Black would
/// each be another file held in memory for weights nothing ever asks for.
/// With only a Regular on offer the engine emboldens it, exactly as it
/// already does for the bundled single-weight display faces.
FontFaceInfo? pickDrawingFace(Iterable<FontFaceInfo> faces) {
  FontFaceInfo? best;
  for (final f in faces) {
    if (f.italic) continue;
    if (best == null) {
      best = f;
      continue;
    }
    final d = (f.weight - 700).abs();
    final bestD = (best.weight - 700).abs();
    if (d != bestD) {
      if (d < bestD) best = f;
    } else if (f.variable != best.variable) {
      if (!f.variable) best = f;
    } else if (f.bytes < best.bytes) {
      best = f;
    }
  }
  return best;
}

/// Scans [directories] and returns the device's Latin-capable font families,
/// sorted by name. Synchronous file I/O throughout: run it off the UI isolate.
///
/// Only files [configs] offer by name are kept (see [namedFontFiles]); where
/// no config can be read, every file is a candidate and the Latin check alone
/// decides, which over-offers rather than hiding the device's fonts.
List<DeviceFontFamily> scanFontDirectories(
  List<String> directories, {
  List<String> configs = kDeviceFontConfigs,
  int maxBytes = kMaxDeviceFontBytes,
}) {
  final named = namedFontFiles(configs);
  final byFamily = <String, List<FontFaceInfo>>{};
  for (final path in directories) {
    final dir = Directory(path);
    if (!dir.existsSync()) continue;
    final List<FileSystemEntity> entries;
    try {
      // Not following links: where a directory has them they are aliases of
      // a file listed in its own right (DroidSans.ttf -> Roboto-Regular.ttf).
      entries = dir.listSync(followLinks: false);
    } catch (_) {
      continue;
    }
    for (final entry in entries) {
      if (entry is! File) continue;
      final lower = entry.path.toLowerCase();
      if (!lower.endsWith('.ttf') && !lower.endsWith('.otf')) continue;
      if (named.isNotEmpty && !named.contains(entry.uri.pathSegments.last)) {
        continue;
      }
      try {
        if (entry.lengthSync() > maxBytes) continue;
      } catch (_) {
        continue;
      }
      final info = readFontFaceInfo(entry.path);
      // A name with a leading dot is the platform's private convention for
      // "not a user-facing family".
      if (info == null || !info.latin || info.family.startsWith('.')) {
        continue;
      }
      byFamily.putIfAbsent(info.family, () => []).add(info);
    }
  }
  final families = <DeviceFontFamily>[
    for (final MapEntry(key: family, value: faces) in byFamily.entries)
      if (pickDrawingFace(faces) case final face?)
        DeviceFontFamily(family, face.path),
  ];
  families.sort(
    (a, b) => a.family.toLowerCase().compareTo(b.family.toLowerCase()),
  );
  return families;
}

/// The device's own fonts: found by a scan, registered with the engine on
/// first use, and offered in the font picker beside the bundled and imported
/// ones.
///
/// Process-wide, because what it manages is: a font registered with the
/// engine stays registered for the life of the process, and every surface
/// that draws a project - the canvas, Home's thumbnails, the export - has to
/// agree on whether a family is loaded. The renderers reach it through
/// [instance]; widgets through [deviceFontsProvider], so a test can swap it.
class DeviceFonts {
  DeviceFonts({
    this.directories = kDeviceFontDirectories,
    this.configs = kDeviceFontConfigs,
  });

  static final DeviceFonts instance = DeviceFonts();

  final List<String> directories;
  final List<String> configs;

  Future<List<DeviceFontFamily>>? _families;
  final Map<String, Future<bool>> _loads = {};

  /// Families some other source draws: the bundled set and the user's
  /// imported fonts. A device font under one of these names is never
  /// registered - it would join that family as a second face, and the engine
  /// would choose between the two by weight.
  final Set<String> _taken = {
    ...AppFonts.bundledFonts,
    AppFonts.ui,
    AppFonts.display,
  };

  /// Claims [family] for another source - see [_taken]. The imported-font
  /// store calls this as it registers each one.
  void reserve(String family) => _taken.add(family);

  /// The device's font families. Scanned once, on first ask, off the UI
  /// isolate - not at startup, because most sessions never open the picker
  /// and never draw a device font.
  Future<List<DeviceFontFamily>> families() =>
      _families ??= _scan(directories, configs);

  /// Registers [family] with the engine if it is one of the device's fonts.
  ///
  /// Completes true once the family can be drawn - including when it was
  /// never the device's to draw (bundled, imported) - and false for a name
  /// nobody on this phone provides, such as a font since removed by an OS
  /// update. That case draws in the fallback face, which is the most anyone
  /// can do for it.
  Future<bool> ensure(String family) {
    if (_taken.contains(family)) return SynchronousFuture(true);
    return _loads[family] ??= _load(family);
  }

  Future<bool> _load(String family) async {
    final match = (await families())
        .where((f) => f.family == family)
        .firstOrNull;
    if (match == null) return false;
    try {
      final bytes = await File(match.path).readAsBytes();
      await (FontLoader(
        family,
      )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Starts loading every device font [layers] draw with, and returns at once.
  ///
  /// For build methods. Nothing has to wait for it: `loadFontFromList`
  /// broadcasts a fonts change when a family lands, and every paragraph on
  /// screen re-lays itself out on that. Cheap enough to call per frame - a
  /// family already settled is one set lookup.
  void prefetch(Iterable<Layer> layers) {
    for (final layer in layers) {
      final family = fontFamilyOf(layer);
      if (family == null ||
          _taken.contains(family) ||
          _loads.containsKey(family)) {
        continue;
      }
      unawaited(ensure(family));
    }
  }

  /// Waits until every device font [layers] draw with is registered.
  ///
  /// What a renderer that paints once - the export - has to do: it gets no
  /// second frame, so a family still loading would be baked into the file in
  /// the fallback face.
  Future<void> ensureFor(Iterable<Layer> layers) async {
    final pending = [
      for (final family in {...layers.map(fontFamilyOf).nonNulls})
        if (!_taken.contains(family)) ensure(family),
    ];
    if (pending.isNotEmpty) await Future.wait(pending);
  }
}

/// The family a layer draws its text in, or null for a photo.
String? fontFamilyOf(Layer layer) => switch (layer) {
  TextLayer(:final fontFamily) => fontFamily,
  BubbleLayer(:final fontFamily) => fontFamily,
  ImageLayer() => null,
};

/// Top-level so the closure sent to the isolate holds only the two lists.
Future<List<DeviceFontFamily>> _scan(
  List<String> directories,
  List<String> configs,
) async {
  // Checked here rather than left to the isolate so that a host - every
  // widget test - never spawns one for directories that cannot exist.
  final present = [
    for (final d in directories)
      if (Directory(d).existsSync()) d,
  ];
  if (present.isEmpty) return const [];
  try {
    return await Isolate.run(
      () => scanFontDirectories(present, configs: configs),
    );
  } catch (_) {
    return const [];
  }
}

final deviceFontsProvider = Provider<DeviceFonts>(
  (ref) => DeviceFonts.instance,
);

/// The device's font families, for the picker.
final deviceFontFamiliesProvider = FutureProvider<List<DeviceFontFamily>>(
  (ref) => ref.watch(deviceFontsProvider).families(),
);
