import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'settings_store.dart';

/// Whether the app renders light, dark, or whatever the device is set to.
///
/// The default is [ThemeMode.system], and that is not a cop-out: the two panels
/// this ships to want opposite things. An AMOLED phone is usually run dark - the
/// app's black surfaces cost it nothing - while an IPS phone is usually run
/// light and turns a dark app into a grey smear in daylight. The device setting
/// already encodes which of those the user is, so following it is right far more
/// often than any single default we could pick.
///
/// The override is persisted (see [SettingsStore.setThemeModeName]) and read
/// back before the first frame, so the app never flashes one theme and then
/// swaps - which on a dark-mode phone would be a white flash into a black app.
class ThemeModeController extends AsyncNotifier<ThemeMode> {
  @override
  Future<ThemeMode> build() async {
    final name = await ref.read(settingsStoreProvider).themeModeName();
    return themeModeFromName(name);
  }

  /// Switches the appearance. Pass [ThemeMode.system] to follow the device.
  ///
  /// The state moves first and the write is awaited after, so the repaint lands
  /// on the same frame as the tap - a settings write is a file write and would
  /// otherwise show as a visible lag on the picker.
  Future<void> setThemeMode(ThemeMode mode) async {
    if (state.asData?.value == mode) return;
    state = AsyncData(mode);
    await ref
        .read(settingsStoreProvider)
        .setThemeModeName(mode == ThemeMode.system ? null : mode.name);
  }
}

final themeModeControllerProvider =
    AsyncNotifierProvider<ThemeModeController, ThemeMode>(
      ThemeModeController.new,
    );

/// Parses a persisted name into a [ThemeMode]. Anything unrecognised - a null,
/// a value written by a newer build, a hand-edited file - reads as
/// [ThemeMode.system] rather than as an error: an unreadable preference must
/// never leave the app in a theme the user cannot see their way out of.
ThemeMode themeModeFromName(String? name) => switch (name) {
  'light' => ThemeMode.light,
  'dark' => ThemeMode.dark,
  _ => ThemeMode.system,
};

/// The appearances offered in Settings, in menu order.
const List<ThemeMode> kAppThemeModes = [
  ThemeMode.system,
  ThemeMode.light,
  ThemeMode.dark,
];
