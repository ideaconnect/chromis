import 'package:chromis/core/models/grid.dart';
import 'package:chromis/features/grid/grid_templates.dart';
import 'package:chromis/features/grid/widgets/grid_template_strip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the Photo Grid template registry (every layout really produces the
/// photo count it is filed under, with canonical cell ids), shape matching
/// across a resize, and the shared template strip.
void main() {
  group('registry', () {
    test('covers 2..5 photos and nothing outside that range', () {
      for (var n = kMinGridPhotos; n <= kMaxGridPhotos; n++) {
        expect(gridTemplatesFor(n), isNotEmpty, reason: '$n photos');
      }
      expect(gridTemplatesFor(1), isEmpty);
      expect(gridTemplatesFor(6), isEmpty);
      expect(gridTemplatesFor(0), isEmpty);
    });

    test('every template has exactly its count of cells, ids c0..cN-1', () {
      for (var n = kMinGridPhotos; n <= kMaxGridPhotos; n++) {
        for (final template in gridTemplatesFor(n)) {
          expect(
            template.cellCount,
            n,
            reason: '"${template.label}" is filed under $n photos',
          );
          expect(
            template.cellIds,
            List.generate(n, (i) => 'c$i'),
            reason: '"${template.label}" ids must be canonical and in order',
          );
        }
      }
    });

    test('labels are unique within a count (they key the strip tiles)', () {
      for (var n = kMinGridPhotos; n <= kMaxGridPhotos; n++) {
        final labels = gridTemplatesFor(n).map((t) => t.label).toList();
        expect(labels.toSet(), hasLength(labels.length), reason: '$n photos');
      }
    });

    test('every template lays out into non-overlapping cells', () {
      for (var n = kMinGridPhotos; n <= kMaxGridPhotos; n++) {
        for (final template in gridTemplatesFor(n)) {
          final layout = layoutGrid(
            GridSpec(root: template.root),
            const Size(1080, 1080),
          );
          expect(layout.cells, hasLength(n));
          final rects = layout.cells.values.toList();
          for (final rect in rects) {
            expect(rect.width, greaterThan(0), reason: template.label);
            expect(rect.height, greaterThan(0), reason: template.label);
          }
          for (var i = 0; i < rects.length; i++) {
            for (var j = i + 1; j < rects.length; j++) {
              expect(
                rects[i].overlaps(rects[j]),
                isFalse,
                reason: '"${template.label}": ${rects[i]} / ${rects[j]}',
              );
            }
          }
        }
      }
    });

    test('defaultGridSpec starts on the first layout and clamps its count', () {
      final three = defaultGridSpec(3);
      expect(three.cellCount, 3);
      expect(three.root.hasSameShapeAs(gridTemplatesFor(3).first.root), isTrue);
      // Out-of-range counts clamp rather than throwing on an empty registry.
      expect(defaultGridTemplate(99).cellCount, kMaxGridPhotos);
      expect(defaultGridTemplate(0).cellCount, kMinGridPhotos);
    });
  });

  group('matchGridTemplate', () {
    test('finds the entry a layout came from', () {
      for (var n = kMinGridPhotos; n <= kMaxGridPhotos; n++) {
        for (final template in gridTemplatesFor(n)) {
          expect(matchGridTemplate(template.root)?.label, template.label);
        }
      }
    });

    test('still matches after the user has dragged a divider', () {
      // Shape is the primary key: a resized "Big left" is still "Big left", so
      // the strip keeps its selection instead of going blank on the first drag.
      final template = gridTemplatesFor(3)[2];
      expect(template.label, 'Big left');
      var spec = GridSpec(root: template.root);
      final divider = layoutGrid(spec, const Size(1080, 1080)).dividers.first;
      spec = moveDivider(spec, divider, 180);

      expect(spec.root, isNot(template.root)); // weights really did change
      expect(matchGridTemplate(spec.root)?.label, template.label);
    });

    test('same-shape entries are told apart by their weights', () {
      // "Side by side" and "Wide left" are both two columns - only the weights
      // differ - so the nearest-weights rule is what keeps them distinct.
      final even = gridTemplatesFor(2)[0];
      final wide = gridTemplatesFor(2)[2];
      expect(even.label, 'Side by side');
      expect(wide.label, 'Wide left');
      expect(even.root.hasSameShapeAs(wide.root), isTrue);

      expect(matchGridTemplate(even.root)?.label, 'Side by side');
      expect(matchGridTemplate(wide.root)?.label, 'Wide left');

      // A small drag keeps the label; a big one reports the layout it now
      // sits closest to, which is the honest answer for the strip to show.
      GridSpec drag(GridTemplate t, double px) {
        final spec = GridSpec(root: t.root);
        return moveDivider(
          spec,
          layoutGrid(spec, const Size(1000, 1000)).dividers.first,
          px,
        );
      }

      expect(matchGridTemplate(drag(even, 30).root)?.label, 'Side by side');
      expect(matchGridTemplate(drag(even, 160).root)?.label, 'Wide left');
    });

    test('returns null for a shape no template has', () {
      final odd = GridSplit(
        GridAxis.rows,
        [1, 1],
        const [GridLeaf('a'), GridLeaf('b')],
      ).withCanonicalIds();
      // Two rows IS a template, so nest it into a shape none of them use.
      final nested = GridSplit(
        GridAxis.columns,
        [1, 1],
        [odd, const GridLeaf('c')],
      ).withCanonicalIds();
      expect(nested.cellCount, 3);
      expect(matchGridTemplate(nested), isNull);
    });
  });

  group('GridTemplateStrip', () {
    Widget host(
      List<GridTemplate> templates,
      int selected,
      void Function(int) onTap,
    ) => MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 400,
          child: GridTemplateStrip(
            templates: templates,
            selectedIndex: selected,
            onSelected: onTap,
          ),
        ),
      ),
    );

    testWidgets('renders one tappable tile per template', (tester) async {
      final templates = gridTemplatesFor(4);
      var tapped = -1;
      await tester.pumpWidget(host(templates, 0, (i) => tapped = i));

      for (final template in templates) {
        expect(
          find.byKey(ValueKey('grid-template-${template.label}')),
          findsOneWidget,
          reason: template.label,
        );
      }

      await tester.tap(
        find.byKey(ValueKey('grid-template-${templates[1].label}')),
      );
      expect(tapped, 1);
    });

    testWidgets('marks only the selected tile as selected', (tester) async {
      final templates = gridTemplatesFor(3);
      await tester.pumpWidget(host(templates, 2, (_) {}));

      final selected = tester
          .widgetList<Semantics>(find.byType(Semantics))
          .where((s) => s.properties.selected ?? false)
          .toList();
      expect(selected, hasLength(1));
      expect(selected.single.properties.label, 'Layout ${templates[2].label}');
    });

    testWidgets('an unmatched layout (index -1) selects nothing', (
      tester,
    ) async {
      await tester.pumpWidget(host(gridTemplatesFor(2), -1, (_) {}));
      expect(
        tester
            .widgetList<Semantics>(find.byType(Semantics))
            .where((s) => s.properties.selected ?? false),
        isEmpty,
      );
    });
  });
}
