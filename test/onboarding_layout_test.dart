import 'package:chromis/core/theme/app_theme.dart';
import 'package:chromis/features/onboarding/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/surface.dart';

/// The first-run intro has to survive a short viewport. Its artwork, title and
/// body add up to a fixed height, so a phone in landscape - or a portrait phone
/// whose system insets leave less room than the design assumed - used to
/// overflow the page rather than let the user scroll to the rest of it. It was
/// a real 40-px overflow on a Pixel emulator, invisible on the default 800x600
/// test surface.
void main() {
  Future<void> pumpAt(WidgetTester tester, Size size) async {
    setSurface(tester, size);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const OnboardingScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
  }

  const sizes = <String, Size>{
    'a tall phone': Size(412, 915),
    'a short phone': Size(360, 600),
    'a phone in landscape': Size(915, 412),
    'a very short window': Size(800, 320),
  };

  for (final entry in sizes.entries) {
    testWidgets('the intro page fits ${entry.key}', (tester) async {
      await pumpAt(tester, entry.value);
      expect(
        tester.takeException(),
        isNull,
        reason: 'onboarding overflowed at ${entry.value}',
      );
      // The page is still usable, not merely non-crashing.
      expect(find.text('Start from a photo'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);
    });
  }

  testWidgets('a viewport too short to show the page scrolls instead', (
    tester,
  ) async {
    await pumpAt(tester, const Size(800, 320));
    final body = find.textContaining('Open any photo');
    expect(body, findsOneWidget);
    // Scrollable, so the copy under the artwork stays reachable.
    await tester.drag(body, const Offset(0, -80));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
