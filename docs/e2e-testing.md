# End-to-end (BDD) testing

Human-readable, Gherkin-driven end-to-end tests that drive the **real app on a
connected device** and produce an HTML report. Built on
[`bdd_widget_test`](https://pub.dev/packages/bdd_widget_test) (a real Flutter BDD
framework - the Behat/Cucumber equivalent) on top of Flutter's `integration_test`.

## One command

```powershell
./e2e.ps1            # Windows (auto-picks the connected Android device)
```
```bash
./e2e.sh             # macOS / Linux / CI
```

It regenerates the tests from the `.feature` files, runs them on the device
(showing live progress), then writes and opens a report at
**`build/e2e-report/index.html`** (plus `report.md` and a console summary).

> These are E2E tests - they **install and drive the real app**, so a device
> must be connected. On Xiaomi/MIUI, accept the **"Install via USB"** prompt on
> the phone when it appears. If no device is connected, the script says so and
> runs nothing.

Options: `./e2e.ps1 -Device <id>` (target a device), `-SkipGen` (skip codegen),
`-NoOpen` (don't open the report).

## How it fits together

```
integration_test/bdd/
  app_launch.feature        # Gherkin - you write these
  editor.feature
  *_test.dart               # GENERATED from the features (do not edit)
test/step/
  *.dart                    # step definitions - you implement these (committed)
  _e2e_support.dart         # shared helpers (settle, bootToHome)
tool/e2e_report.dart        # JSON test output -> HTML/Markdown report
e2e.ps1 / e2e.sh            # the launcher
build.yaml                  # bdd_widget_test codegen config
```

`bdd_widget_test` sees the features are under `integration_test/` and generates
tests that use `IntegrationTestWidgetsFlutterBinding` (i.e. real on-device runs).

## Writing a scenario

1. Add or edit a `*.feature` file under `integration_test/bdd/` in plain Gherkin:

   ```gherkin
   Feature: Core editing on a blank canvas

     Scenario: Add a comic bubble layer
       Given the app is freshly launched
       When I create a new blank project
       And I tap the {'Bubble'} tool
       Then a comic bubble layer is added
       And no unhandled error occurred
   ```
   Parameters use `{'...'}` for strings / `{42}` for ints. Keep the free-text
   `Feature:` description from starting a line with a Gherkin keyword
   (Given/When/Then/And) - that line would be misparsed as a step.

2. Regenerate: `dart run build_runner build` (or just run `./e2e.ps1`).

3. Any **new** step phrase gets a stub in `test/step/<snake_case>.dart` that
   throws `UnimplementedError()`. Implement it - the function receives a
   `WidgetTester` (plus a `String param1`, etc. for `{...}` params). Existing
   step files are never overwritten, and identical phrases reuse one step.

### Step conventions used here

- `pumpAndSettle` **hangs** on this app (the splash spinner, onboarding dots and
  Home banner-ad slot never settle) - use the shared `settle(tester)` which
  pumps fixed frames instead.
- `bootToHome(tester)` launches the real app and skips first-run onboarding.
- Assert real state where UI text is ambiguous - e.g. the bubble step reads
  `editorControllerProvider.layers` via `ProviderScope.containerOf(...)`.

## What it can and can't cover

Covered on-device: install + cold start (real ONNX/ML Kit/ads/font/routing
init), reaching Home, creating a project, opening the editor, and blank-canvas
edits (bubble/text layers).

Not automatable here: flows behind the **system photo picker** (import → crop,
AI background cut, MI-GAN fill, export/share) need platform-channel mocking, so
they stay in manual device testing. See [device-testing notes](../MEMORY.md).
