import 'dart:io';

import 'package:chromis/core/settings/settings_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// Contract for [SettingsStore]: booleans default false and string prefs null
/// until written, writes persist across store instances (re-read from disk),
/// independent keys don't clobber each other, and a corrupt settings.json is
/// treated as empty rather than throwing. dart:io only, no platform channels.
void main() {
  /// A temp dir torn down after the current test; the settings file lives
  /// directly at `<base>/settings.json`.
  Directory freshTemp() {
    final dir = Directory.systemTemp.createTempSync('settings_store_test');
    addTearDown(() => dir.deleteSync(recursive: true));
    return dir;
  }

  test('onboardingSeen defaults to false and persists when set', () async {
    final base = freshTemp();
    final store = SettingsStore(baseDir: base);

    expect(await store.onboardingSeen(), isFalse);

    await store.setOnboardingSeen(true);
    // Re-read via a fresh instance to prove it went to disk, not memory.
    expect(await SettingsStore(baseDir: base).onboardingSeen(), isTrue);

    await store.setOnboardingSeen(false);
    expect(await SettingsStore(baseDir: base).onboardingSeen(), isFalse);
  });

  test('segmentationModelId is null until set, then round-trips', () async {
    final base = freshTemp();
    final store = SettingsStore(baseDir: base);

    expect(await store.segmentationModelId(), isNull);

    await store.setSegmentationModelId('u2netp');
    expect(await SettingsStore(baseDir: base).segmentationModelId(), 'u2netp');
  });

  test('proEntitled defaults to false and toggles both ways', () async {
    final base = freshTemp();
    final store = SettingsStore(baseDir: base);

    expect(await store.proEntitled(), isFalse);

    await store.setProEntitled(true);
    expect(await SettingsStore(baseDir: base).proEntitled(), isTrue);

    await store.setProEntitled(false);
    expect(await SettingsStore(baseDir: base).proEntitled(), isFalse);
  });

  test('independent keys do not clobber one another', () async {
    final base = freshTemp();
    final store = SettingsStore(baseDir: base);

    await store.setOnboardingSeen(true);
    await store.setProEntitled(true);
    await store.setSegmentationModelId('mlkit');

    final reread = SettingsStore(baseDir: base);
    expect(await reread.onboardingSeen(), isTrue);
    expect(await reread.proEntitled(), isTrue);
    expect(await reread.segmentationModelId(), 'mlkit');
  });

  test('a corrupt settings.json reads as empty and never throws', () async {
    final base = freshTemp();
    File('${base.path}/settings.json').writeAsStringSync('} not json {');
    final store = SettingsStore(baseDir: base);

    // Every getter falls back to its default rather than surfacing the error.
    expect(await store.onboardingSeen(), isFalse);
    expect(await store.proEntitled(), isFalse);
    expect(await store.segmentationModelId(), isNull);

    // And a subsequent write still succeeds (overwrites the garbage).
    await store.setOnboardingSeen(true);
    expect(await SettingsStore(baseDir: base).onboardingSeen(), isTrue);
  });
}
