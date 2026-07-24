# CLAUDE.md — Chromis

Guidance for AI coding sessions on this repo.

## What this is

Free, ad-supported Flutter **Android** photo editor with on-device AI (BG removal,
object removal, layers, text, comic bubbles, export). Built from the approved
Claude Design mockup, reusing IDCT Sticker Maker's engine code.

## Architecture

Feature-first: `lib/app` (root + `go_router`), `lib/core` (theme, models,
rendering, widgets), `lib/features/*`. State via `flutter_riverpod`. Dark-only
theme — read colors from `AppColors` and design tokens from `context.sm`
(`SmTokens`); fonts are **Manrope** (body) + **Space Grotesk** (`AppFonts`).

## Milestones

Planned as GitHub milestones **M0–M9** with issues. Work one milestone at a time;
**after each milestone, stop and ask the user to test-deploy on their physical
device** before starting the next (device deploys need their acknowledgement).

## On-device AI (reused from Sticker Maker)

`lib/features/segmentation/**` — engine abstraction + registry, ML Kit engine,
bundled U²-Netp (ONNX) engine, MobileSAM object engine, mask brush/processing.
Models in `assets/models/*.onnx` (Apache-2.0). Runs via `flutter_onnxruntime`.

## Monetization

`google_mobile_ads` (banner/interstitial/rewarded + UMP) and `in_app_purchase`
(one-time `pro_remove_ads`). Ad unit IDs live in one config file; Google **test**
IDs are placeholders until the real ones are set. See `docs/monetization-setup.md`.

## Licensing policy (closed-source app)

Bundle **only** MIT / BSD / Apache-2.0 / SIL-OFL. No GPL/LGPL (ffmpeg dropped),
no CC-BY-NC (no `u2net_portrait` / BRIA RMBG). Register bundled font + model
license texts in `lib/features/about/bundled_licenses.dart`.

## Commands

```bash
flutter analyze        # keep clean
flutter test           # keep green
dart format .          # CI enforces formatting
flutter build apk --debug
```

Identity: applicationId `tech.idct.chromis`, namespace `tech.idct.chromis`, minSdk 26.
