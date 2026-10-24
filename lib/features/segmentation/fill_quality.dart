import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/platform/platform_services.dart';
import '../../core/settings/settings_store.dart';

/// How Fill rebuilds the background behind a removed object (#68) - the
/// user's choice, made the first time they fill and changeable in the
/// Remove-object panel.
///
/// The two are the two fill tiers, named by what they cost and give rather
/// than by model: [best] is MI-GAN, falling back to content-aware fill;
/// [lowMemory] is content-aware fill alone. Measured on the emulator with a
/// 2048 px photo, MI-GAN peaked 454-460 MB above the app's resident size and
/// took 7.6-24.6 s; content-aware fill peaked 39-46 MB above it and took
/// 1.6-3.0 s. On a 2 GB phone those 460 MB are the difference between a fill
/// and a device that stops scheduling the main thread (#66).
enum FillQuality {
  best('best'),
  lowMemory('lowMemory');

  const FillQuality(this.id);

  /// Stable key persisted in settings.
  final String id;

  /// A persisted [id] back to a choice, or null when there is none - which
  /// includes a value written by a newer build or a hand-edited file. Null
  /// means "never chose", so the next fill asks rather than guessing silently.
  static FillQuality? fromId(String? id) {
    for (final q in values) {
      if (q.id == id) return q;
    }
    return null;
  }
}

/// Below this much total RAM the recommendation is [FillQuality.lowMemory].
/// A 2 GB phone cannot spare MI-GAN's 460 MB on top of the app, the launcher
/// and Play services; a 4 GB one can.
const int fillBestMinTotalMemBytes = 3 * 1024 * 1024 * 1024;

/// ...and below this much memory free right now. Twice MI-GAN's peak, so the
/// rest of the phone keeps something after the fill has taken its share.
const int fillBestMinAvailMemBytes = 1024 * 1024 * 1024;

/// The choice offered first, from what the phone says about its memory.
///
/// Only a positive signal recommends [FillQuality.lowMemory] - a low-RAM
/// device, too little RAM, or too little free - the same rule the SAM tier's
/// gate uses. When the platform cannot answer at all, [FillQuality.best]:
/// this only preselects an option the user then confirms, and a guess that
/// errs towards quality is one they can see and change.
FillQuality recommendFillQuality(MemoryInfo? info) {
  if (info == null) return FillQuality.best;
  if (info.lowRam ||
      info.totalMem < fillBestMinTotalMemBytes ||
      info.availMem < fillBestMinAvailMemBytes) {
    return FillQuality.lowMemory;
  }
  return FillQuality.best;
}

/// The recommendation for this phone, probed once per app run - the first
/// time the Remove-object panel or the first-fill prompt asks for it, so it
/// reads the memory free at that moment rather than at launch.
final fillQualityRecommendationProvider = FutureProvider<FillQuality>(
  (ref) async => recommendFillQuality(
    await ref.read(platformServicesProvider).memoryInfo(),
  ),
);

/// The persisted [FillQuality], or null until the user has chosen one.
class FillQualityController extends AsyncNotifier<FillQuality?> {
  @override
  Future<FillQuality?> build() async =>
      FillQuality.fromId(await ref.read(settingsStoreProvider).fillQualityId());

  /// Selects [quality] optimistically, so the panel updates on the tap, and
  /// persists it.
  Future<void> select(FillQuality quality) async {
    state = AsyncData(quality);
    await ref.read(settingsStoreProvider).setFillQualityId(quality.id);
  }
}

final fillQualityProvider =
    AsyncNotifierProvider<FillQualityController, FillQuality?>(
      FillQualityController.new,
    );

/// Runs the fill tiers [quality] allows, best first, and returns the first
/// result - or null when none produced one, which the editor answers by
/// erasing instead.
///
/// [FillQuality.best] still tries [generative] unconditionally and treats its
/// null as "fall through": the choice is the user's, not an availability
/// check, and the generative tier has been skipped by a pre-flight "is the
/// model there?" gate three times before (see `_tryInpaint`).
/// [FillQuality.lowMemory] never calls it, which is the point of choosing it.
Future<Uint8List?> runFill(
  FillQuality quality, {
  required Future<Uint8List?> Function() generative,
  required Future<Uint8List?> Function() contentAware,
}) async {
  if (quality == FillQuality.best) {
    final generated = await generative();
    if (generated != null) return generated;
  }
  return contentAware();
}
