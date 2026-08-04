import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'features/about/bundled_licenses.dart';
import 'features/home/project_repository.dart';

/// The orientations the app allows.
///
/// Landscape is a first-class layout in the editor - a rail down the left, a
/// folding tool panel, and the rest of the screen for the picture - so the app
/// has to be allowed to turn. It was locked to portraitUp, which made all of
/// that unreachable no matter how the layout responded; that is what the test
/// beside this constant exists to stop happening again.
///
/// portraitDown stays out: nothing here benefits from an upside-down phone, and
/// it makes the camera and picker hand-offs odd.
const List<DeviceOrientation> supportedOrientations = [
  DeviceOrientation.portraitUp,
  DeviceOrientation.landscapeLeft,
  DeviceOrientation.landscapeRight,
];

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  registerBundledLicenses();
  // Cold launch is the safe moment (no editor open, no undo stacks) to drop
  // orphaned image/mask files - e.g. superseded erase masks (#76). The sweep
  // does its filesystem work inside Isolate.run, so it never competes with
  // first-frame work on the UI isolate.
  unawaited(
    ProjectRepository().sweepOrphanAssets().then((_) => 0, onError: (_) => 0),
  );
  SystemChrome.setPreferredOrientations(supportedOrientations);
  // Only the pre-first-frame value: it has to match the native splash, which
  // is dark whatever theme the user has chosen. From the first frame on, the
  // `AnnotatedRegion` in `ChromisApp` owns this and follows the live theme -
  // see `systemOverlayStyleFor`. Do not put a palette colour here; `main` runs
  // before the saved appearance has been read.
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0A1526),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const ProviderScope(child: ChromisApp()));
}
