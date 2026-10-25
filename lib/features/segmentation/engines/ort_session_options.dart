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
///
/// **The Gelu fusions are off.** MobileSAM ships as fp16, and its GELUs are
/// written out as `Erf` arithmetic. ORT 1.28's graph optimizer fuses that into
/// one `com.microsoft.Gelu` node typed fp16 - on an ARM CPU with fp16
/// arithmetic, which is nearly every phone sold since 2018 - and then finds no
/// fp16 kernel for the node it made, so the encoder session refuses to
/// create: `ORT_NOT_IMPLEMENTED: Failed to find kernel for com.microsoft.Gelu`.
/// 1.4.2 shipped that, and Remove object read as "not available on this
/// device" on a Xiaomi 15 Ultra. An x86 emulator has no fp16 path, so the
/// fusion never fires there and every device test passed. Unfused, ORT runs
/// the `Erf` steps as it did on 1.23. The other models are fp32 with at most
/// one `Erf`, so they lose nothing measurable.
///
/// The list is split on `;`, not `,` - ORT's `SplitString(..., ";")`. With a
/// comma the whole value is one unknown name, nothing is disabled, and nothing
/// says so.
const Map<String, String> kOrtSessionConfigs = {
  'mlas.disable_kleidiai': '1',
  'optimization.disable_specified_optimizers': 'GeluFusionL1;GeluFusionL2',
};

/// The options for every ORT session - the one place they are defined, so no
/// model can be loaded without them. `test/segmentation/ort_session_options_test.dart`
/// fails if a `createSession` call in `lib/` does not pass this.
///
/// **The CPU memory arena is off** (#66). ORT's arena grows to fit a run and
/// hands nothing back while its session lives - and every session here but
/// the SAM encoder lives for the whole process. Measured on an emulator with a
/// 2048 px photo: one U²-Net cut kept 200 MB, and two MI-GAN fills kept
/// 1.1 GB, so the app sat at 1.4 GB after a couple of taps. On a 2 GB phone
/// that is the whole device: zram thrash in which nothing, the main thread
/// included, gets scheduled for seconds - an input ANR whose trace shows an
/// idle `nativePollOnce`. Without the arena the same two fills keep 44 MB and
/// run no slower, and the process peak falls too, from 1.6 GB to 1.0 GB.
OrtSessionOptions ortSessionOptions() =>
    OrtSessionOptions(sessionConfigs: kOrtSessionConfigs, useArena: false);
