import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../persistence/atomic_file.dart';

/// Tiny key/value app settings, persisted as a single `settings.json` under the
/// app documents directory. Currently just the first-run flag; kept generic so
/// future preferences (default export target, etc.) slot in without a new file.
/// Pass [baseDir] in tests to use a temp directory.
class SettingsStore {
  SettingsStore({Directory? baseDir}) : _baseOverride = baseDir;

  final Directory? _baseOverride;

  static const _fileName = 'settings.json';
  static const _kOnboardingSeen = 'onboardingSeen';
  static const _kSegModel = 'segmentationModel';
  static const _kProEntitled = 'proEntitled';
  static const _kRestoreProbed = 'restoreProbed';
  static const _kLocale = 'locale';
  static const _kThemeMode = 'themeMode';

  Future<File> _file() async {
    final base = _baseOverride ?? await getApplicationDocumentsDirectory();
    return File('${base.path}/$_fileName');
  }

  Future<Map<String, dynamic>> _read() async {
    final file = await _file();
    if (!file.existsSync()) return {};
    try {
      return (jsonDecode(await file.readAsString()) as Map)
          .cast<String, dynamic>();
    } catch (_) {
      // A corrupt settings file should never brick the app - treat as empty.
      return {};
    }
  }

  /// Atomic on purpose - see [writeFileAtomically]. Every value in this file is
  /// one the user cannot re-enter: a truncated write reads back as `{}`, which
  /// silently un-buys Pro (and [EntitlementController] will not restore it,
  /// since `reconcileEntitlement` self-excludes once the flag is already false).
  Future<void> _write(Map<String, dynamic> data) async {
    await writeFileAtomically(await _file(), jsonEncode(data));
  }

  /// Whether the first-run intro has been completed (or skipped).
  Future<bool> onboardingSeen() async =>
      (await _read())[_kOnboardingSeen] == true;

  Future<void> setOnboardingSeen(bool value) async {
    final data = await _read();
    data[_kOnboardingSeen] = value;
    await _write(data);
  }

  /// The user's preferred background-removal model id (see `SegModel`), or null
  /// when unset - the segmentation layer maps that to its default. Stored as a
  /// bare string so this core layer stays free of any feature dependency.
  Future<String?> segmentationModelId() async =>
      (await _read())[_kSegModel] as String?;

  Future<void> setSegmentationModelId(String id) async {
    final data = await _read();
    data[_kSegModel] = id;
    await _write(data);
  }

  /// Whether the one-time "Go Pro - remove ads" purchase is owned. Cached
  /// locally so Pro survives offline; re-verified via Restore on reinstall.
  Future<bool> proEntitled() async => (await _read())[_kProEntitled] == true;

  Future<void> setProEntitled(bool value) async {
    final data = await _read();
    data[_kProEntitled] = value;
    await _write(data);
  }

  /// Whether this install has already asked Play "does this account own Pro?".
  /// Set only after a query that actually reached Play, so a first launch with
  /// no connection retries rather than silently giving up on a paying user.
  Future<bool> restoreProbed() async =>
      (await _read())[_kRestoreProbed] == true;

  Future<void> setRestoreProbed(bool value) async {
    final data = await _read();
    data[_kRestoreProbed] = value;
    await _write(data);
  }

  /// The language tag the user picked in Settings (e.g. `en`, `pl`), or null
  /// when they never picked one - which means "follow the device", not
  /// "English". The two differ: a Polish phone must get Polish on first launch,
  /// and must keep following the phone if the user later changes its language.
  Future<String?> localeTag() async => (await _read())[_kLocale] as String?;

  /// Pass null to go back to following the device. The key is REMOVED rather
  /// than written as null, so "never chose" and "chose system" stay the same
  /// state and there is nothing stale to misread on the next launch.
  Future<void> setLocaleTag(String? tag) async {
    final data = await _read();
    if (tag == null) {
      data.remove(_kLocale);
    } else {
      data[_kLocale] = tag;
    }
    await _write(data);
  }

  /// The appearance the user picked in Settings (`light` / `dark`), or null
  /// when they never picked one - which means "follow the device", not "dark".
  /// Same shape as [localeTag] and for the same reason: a phone that switches
  /// to its night theme at sunset must take the app with it.
  Future<String?> themeModeName() async =>
      (await _read())[_kThemeMode] as String?;

  /// Pass null to go back to following the device. The key is REMOVED rather
  /// than written as null, so "never chose" and "chose System" stay one state.
  Future<void> setThemeModeName(String? name) async {
    final data = await _read();
    if (name == null) {
      data.remove(_kThemeMode);
    } else {
      data[_kThemeMode] = name;
    }
    await _write(data);
  }
}

final settingsStoreProvider = Provider<SettingsStore>((ref) => SettingsStore());

/// Resolves to whether onboarding is done. The app shell watches this to pick
/// its start route; invalidate it after completing onboarding.
final onboardingSeenProvider = FutureProvider<bool>(
  (ref) => ref.read(settingsStoreProvider).onboardingSeen(),
);
