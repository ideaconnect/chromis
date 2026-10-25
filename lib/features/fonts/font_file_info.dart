import 'dart:io';

import 'package:flutter/foundation.dart';

/// What the font picker needs to know about one font file, read from its sfnt
/// tables - `name`, `OS/2` and `cmap` - without loading the rest of the file.
///
/// Reading whole files is not an option for a scan: a phone's font directory
/// holds a couple of hundred of them, a CJK collection alone is 20 MB or more,
/// and all that is wanted from each is a name and a few flags.
@immutable
class FontFaceInfo {
  const FontFaceInfo({
    required this.path,
    required this.family,
    required this.weight,
    required this.italic,
    required this.latin,
    required this.variable,
    required this.bytes,
  });

  final String path;

  /// The typographic family (name id 16), falling back to the legacy family
  /// (id 1). The legacy name of a static "Roboto Medium" is "Roboto Medium";
  /// its typographic family is "Roboto", which is what groups it with the rest.
  final String family;

  /// `OS/2.usWeightClass`; 400 when the table is missing.
  final int weight;

  final bool italic;

  /// Maps every one of A-Z and a-z. Most of a phone's font directory is Noto
  /// script fallbacks - Bengali, Armenian, emoji - which Flutter already falls
  /// back to by itself, and as a caption choice they would only draw boxes.
  final bool latin;

  /// Has an `fvar` table. Flutter draws a runtime-loaded variable font at its
  /// default instance, so a static face is preferred when both exist.
  final bool variable;

  final int bytes;

  @override
  String toString() =>
      'FontFaceInfo($family, w$weight${italic ? ' italic' : ''}, $path)';
}

/// Reads [path]'s font tables. Null for anything that is not a single
/// TrueType / OpenType font - a collection, a truncated file, a stray
/// non-font - or that cannot be read.
FontFaceInfo? readFontFaceInfo(String path) {
  RandomAccessFile? file;
  try {
    file = File(path).openSync();
    final length = file.lengthSync();
    final header = _read(file, 0, 12);
    if (header == null) return null;
    final tag = header.getUint32(0);
    // 0x00010000 TrueType, 'OTTO' CFF, 'true' old Apple TrueType. A 'ttcf'
    // collection is refused: those are the CJK fonts, kept out on size anyway.
    if (tag != 0x00010000 && tag != 0x4F54544F && tag != 0x74727565) {
      return null;
    }
    final numTables = header.getUint16(4);
    final dir = _read(file, 12, numTables * 16);
    if (dir == null) return null;
    final tables = <int, ({int offset, int length})>{};
    for (var i = 0; i < numTables; i++) {
      final at = i * 16;
      final offset = dir.getUint32(at + 8);
      final size = dir.getUint32(at + 12);
      if (offset + size > length) continue;
      tables[dir.getUint32(at)] = (offset: offset, length: size);
    }

    final name = tables[_tag('name')];
    if (name == null) return null;
    final names = _read(file, name.offset, name.length);
    if (names == null) return null;
    final family = (_nameRecord(names, 16) ?? _nameRecord(names, 1))?.trim();
    if (family == null || family.isEmpty) return null;

    var weight = 400;
    var italic = false;
    final os2 = tables[_tag('OS/2')];
    if (os2 != null && os2.length >= 64) {
      final t = _read(file, os2.offset, 64);
      if (t != null) {
        weight = t.getUint16(4);
        final fsSelection = t.getUint16(62);
        // Bit 0 ITALIC, bit 9 OBLIQUE.
        italic = fsSelection & 0x201 != 0;
      }
    }

    final cmap = tables[_tag('cmap')];
    final glyphs = cmap == null ? null : _readCmap(file, cmap.offset);
    final latin = glyphs != null && _latinLetters.every((c) => glyphs(c) != 0);

    return FontFaceInfo(
      path: path,
      family: family,
      weight: weight,
      italic: italic,
      latin: latin,
      variable: tables.containsKey(_tag('fvar')),
      bytes: length,
    );
  } catch (_) {
    return null;
  } finally {
    file?.closeSync();
  }
}

/// A-Z and a-z.
final List<int> _latinLetters = [
  for (var c = 0x41; c <= 0x5A; c++) c,
  for (var c = 0x61; c <= 0x7A; c++) c,
];

int _tag(String s) =>
    s.codeUnitAt(0) << 24 |
    s.codeUnitAt(1) << 16 |
    s.codeUnitAt(2) << 8 |
    s.codeUnitAt(3);

ByteData? _read(RandomAccessFile file, int offset, int length) {
  if (length <= 0) return null;
  file.setPositionSync(offset);
  final bytes = file.readSync(length);
  if (bytes.length < length) return null;
  return ByteData.sublistView(bytes);
}

/// The string for [id] in a `name` table, preferring a Windows US-English
/// record, then any Windows or Unicode one, then a Mac Roman one.
String? _nameRecord(ByteData t, int id) {
  final count = t.getUint16(2);
  final storage = t.getUint16(4);
  String? best;
  var bestRank = 99;
  for (var i = 0; i < count; i++) {
    final at = 6 + i * 12;
    if (at + 12 > t.lengthInBytes) break;
    if (t.getUint16(at + 6) != id) continue;
    final platform = t.getUint16(at);
    final encoding = t.getUint16(at + 2);
    final language = t.getUint16(at + 4);
    final length = t.getUint16(at + 8);
    final offset = storage + t.getUint16(at + 10);
    if (offset + length > t.lengthInBytes) continue;
    final int rank;
    final bool utf16;
    if (platform == 3 && (encoding == 1 || encoding == 10)) {
      rank = language == 0x0409 ? 0 : 1;
      utf16 = true;
    } else if (platform == 0) {
      rank = 2;
      utf16 = true;
    } else if (platform == 1 && encoding == 0 && language == 0) {
      rank = 3;
      utf16 = false;
    } else {
      continue;
    }
    if (rank >= bestRank) continue;
    final codes = <int>[
      if (utf16)
        for (var j = 0; j + 1 < length; j += 2) t.getUint16(offset + j)
      else
        for (var j = 0; j < length; j++) t.getUint8(offset + j),
    ];
    best = String.fromCharCodes(codes);
    bestRank = rank;
  }
  return best;
}

/// A code point -> glyph id lookup over the font's best Unicode `cmap`
/// subtable, or null when it has none this understands (formats 4 and 12
/// cover every font a phone ships).
int Function(int)? _readCmap(RandomAccessFile file, int tableOffset) {
  final head = _read(file, tableOffset, 4);
  if (head == null) return null;
  final count = head.getUint16(2);
  final records = _read(file, tableOffset + 4, count * 8);
  if (records == null) return null;
  int? pick;
  var pickRank = 99;
  for (var i = 0; i < count; i++) {
    final platform = records.getUint16(i * 8);
    final encoding = records.getUint16(i * 8 + 2);
    final offset = records.getUint32(i * 8 + 4);
    final rank = switch ((platform, encoding)) {
      (3, 10) => 0,
      (0, 4) || (0, 6) => 1,
      (3, 1) => 2,
      (0, _) => 3,
      _ => 99,
    };
    if (rank < pickRank) {
      pick = offset;
      pickRank = rank;
    }
  }
  if (pick == null) return null;
  final at = tableOffset + pick;
  final sub = _read(file, at, 8);
  if (sub == null) return null;
  switch (sub.getUint16(0)) {
    case 4:
      final t = _read(file, at, sub.getUint16(2));
      return t == null ? null : (c) => _format4(t, c);
    case 12:
      final t = _read(file, at, sub.getUint32(4));
      return t == null ? null : (c) => _format12(t, c);
    default:
      return null;
  }
}

int _format4(ByteData t, int c) {
  if (c > 0xFFFF) return 0;
  final segX2 = t.getUint16(6);
  const ends = 14;
  final starts = ends + segX2 + 2;
  final deltas = starts + segX2;
  final ranges = deltas + segX2;
  for (var i = 0; i < segX2; i += 2) {
    if (t.getUint16(ends + i) < c) continue;
    final start = t.getUint16(starts + i);
    if (start > c) return 0;
    final delta = t.getUint16(deltas + i);
    final range = t.getUint16(ranges + i);
    if (range == 0) return (c + delta) & 0xFFFF;
    final glyphAt = ranges + i + range + 2 * (c - start);
    if (glyphAt + 2 > t.lengthInBytes) return 0;
    final glyph = t.getUint16(glyphAt);
    return glyph == 0 ? 0 : (glyph + delta) & 0xFFFF;
  }
  return 0;
}

int _format12(ByteData t, int c) {
  final groups = t.getUint32(12);
  for (var g = 0; g < groups; g++) {
    final at = 16 + g * 12;
    if (at + 12 > t.lengthInBytes) return 0;
    final start = t.getUint32(at);
    if (c < start) return 0;
    if (c <= t.getUint32(at + 4)) return t.getUint32(at + 8) + (c - start);
  }
  return 0;
}
