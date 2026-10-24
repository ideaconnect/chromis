import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:chromis/core/settings/settings_store.dart';
import 'package:chromis/features/segmentation/fill_quality.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// How Fill rebuilds the background (#68): Best quality (MI-GAN, falling back
/// to content-aware fill) or Low memory (content-aware fill alone), chosen by
/// the user, with a first guess from the phone's memory.
void main() {
  const gib = 1024 * 1024 * 1024;

  group('recommendFillQuality', () {
    test('a 2 GB phone is offered Low memory', () {
      // The Infinix Smart 7 HD that #66 came from. MI-GAN's 460 MB on top of
      // the app is the whole of what such a phone has to spare.
      expect(
        recommendFillQuality((
          totalMem: 2 * gib,
          availMem: 900 * 1024 * 1024,
          lowRam: false,
        )),
        FillQuality.lowMemory,
      );
    });

    test('a 4 GB phone with room to spare is offered Best quality', () {
      expect(
        recommendFillQuality((
          totalMem: 4 * gib,
          availMem: 3 * gib ~/ 2,
          lowRam: false,
        )),
        FillQuality.best,
      );
    });

    test('any one positive signal is enough for Low memory', () {
      // Android's own low-RAM flag, whatever the total says.
      expect(
        recommendFillQuality((
          totalMem: 4 * gib,
          availMem: 2 * gib,
          lowRam: true,
        )),
        FillQuality.lowMemory,
      );
      // A big phone that is short of free memory right now.
      expect(
        recommendFillQuality((
          totalMem: 8 * gib,
          availMem: 600 * 1024 * 1024,
          lowRam: false,
        )),
        FillQuality.lowMemory,
      );
    });

    test('the thresholds are where they say they are', () {
      expect(
        recommendFillQuality((
          totalMem: fillBestMinTotalMemBytes,
          availMem: fillBestMinAvailMemBytes,
          lowRam: false,
        )),
        FillQuality.best,
      );
      expect(
        recommendFillQuality((
          totalMem: fillBestMinTotalMemBytes - 1,
          availMem: 2 * gib,
          lowRam: false,
        )),
        FillQuality.lowMemory,
      );
    });

    test('a phone that cannot say is offered Best quality', () {
      // Only a positive signal moves the guess - the SAM gate's rule. The user
      // confirms it either way, so erring towards quality is visible.
      expect(recommendFillQuality(null), FillQuality.best);
    });
  });

  group('FillQuality.fromId', () {
    test('every choice round-trips through its id', () {
      for (final q in FillQuality.values) {
        expect(FillQuality.fromId(q.id), q);
      }
    });

    test('nothing stored, or something unknown, is "never chose"', () {
      // Null is what makes the first fill ask; a value from a newer build must
      // ask too rather than be read as one of today's two.
      expect(FillQuality.fromId(null), isNull);
      expect(FillQuality.fromId('ultra'), isNull);
    });
  });

  group('runFill', () {
    final generated = Uint8List.fromList([1]);
    final contentFilled = Uint8List.fromList([2]);

    test('Low memory never starts the generative tier', () async {
      var generativeCalls = 0;
      final out = await runFill(
        FillQuality.lowMemory,
        generative: () async {
          generativeCalls++;
          return generated;
        },
        contentAware: () async => contentFilled,
      );
      expect(out, contentFilled);
      expect(
        generativeCalls,
        0,
        reason: 'the point of Low memory is that MI-GAN never runs',
      );
    });

    test('Best quality takes the generative result', () async {
      var contentCalls = 0;
      final out = await runFill(
        FillQuality.best,
        generative: () async => generated,
        contentAware: () async {
          contentCalls++;
          return contentFilled;
        },
      );
      expect(out, generated);
      expect(contentCalls, 0);
    });

    test('Best quality falls through when the generative tier has nothing', () {
      // A missing asset, an ORT failure: `inpaint` answers null for all of
      // them, and Fill must still fill.
      expect(
        runFill(
          FillQuality.best,
          generative: () async => null,
          contentAware: () async => contentFilled,
        ),
        completion(contentFilled),
      );
    });
  });

  group('persistence', () {
    Directory freshTemp() {
      final dir = Directory.systemTemp.createTempSync('fill_quality_test');
      addTearDown(() => dir.deleteSync(recursive: true));
      return dir;
    }

    test(
      'the choice survives a restart, and clearing it removes the key',
      () async {
        final dir = freshTemp();
        final store = SettingsStore(baseDir: dir);
        expect(await store.fillQualityId(), isNull);

        await store.setFillQualityId(FillQuality.lowMemory.id);
        expect(
          await SettingsStore(baseDir: dir).fillQualityId(),
          FillQuality.lowMemory.id,
        );

        await store.setFillQualityId(null);
        final json =
            jsonDecode(File('${dir.path}/settings.json').readAsStringSync())
                as Map;
        expect(
          json.containsKey('fillQuality'),
          isFalse,
          reason: 'removed, not null - "never chose" is one state',
        );
      },
    );

    test(
      'the controller reads the stored choice and writes a new one',
      () async {
        final dir = freshTemp();
        final container = ProviderContainer(
          overrides: [
            settingsStoreProvider.overrideWithValue(
              SettingsStore(baseDir: dir),
            ),
          ],
        );
        addTearDown(container.dispose);

        expect(await container.read(fillQualityProvider.future), isNull);
        await container
            .read(fillQualityProvider.notifier)
            .select(FillQuality.best);
        expect(container.read(fillQualityProvider).value, FillQuality.best);
        expect(
          await SettingsStore(baseDir: dir).fillQualityId(),
          FillQuality.best.id,
        );
      },
    );
  });
}
