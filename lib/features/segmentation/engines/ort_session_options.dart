import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

/// Session config entries every ONNX Runtime session in the app is created
/// with, passed straight to ORT's `AddSessionConfigEntry`.
///
/// **KleidiAI is off** (#64). ORT 1.23 switched its KleidiAI MLAS kernels on
/// whenever the CPU reported SME, but those kernels are SME2 code - so on
/// Snapdragon 8 Gen 5 / 8 Elite Gen 5, which have SME and not SME2 (Galaxy
/// S26, razr fold, OnePlus 15), the first MobileSAM encoder pass executed an
/// illegal instruction. A SIGILL kills the process: no Dart `try` runs, so the
/// app closed every time Remove object was opened. ORT 1.28 chooses between
/// SME and SME2 kernels at runtime, which should be enough on its own; turning
/// KleidiAI off as well means the crash no longer rests on that detection
/// being right on chips this project has no device for.
///
/// It costs nothing anywhere else: MLAS only installs KleidiAI on SME CPUs in
/// the first place, so every other phone was already on the NEON kernels this
/// falls back to.
const Map<String, String> kOrtSessionConfigs = {'mlas.disable_kleidiai': '1'};

/// The options for every ORT session - the one place they are defined, so no
/// model can be loaded without them. `test/segmentation/ort_session_options_test.dart`
/// fails if a `createSession` call in `lib/` does not pass this.
OrtSessionOptions ortSessionOptions() =>
    OrtSessionOptions(sessionConfigs: kOrtSessionConfigs);
