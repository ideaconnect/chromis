import 'dart:ui' show Offset, Rect, Color, Size;

import 'package:chromis/core/models/frame.dart';
import 'package:chromis/core/models/grid.dart';
import 'package:chromis/core/models/image_adjustments.dart';
import 'package:chromis/core/models/layer.dart';
import 'package:chromis/core/models/layer_transform.dart';
import 'package:chromis/core/models/project.dart';
import 'package:chromis/core/rendering/canvas_geometry.dart';
import 'package:chromis/features/editor/state/editor_controller.dart';
import 'package:chromis/features/editor/state/editor_state.dart';
import 'package:chromis/features/editor/state/editor_tool.dart';
import 'package:chromis/features/grid/grid_templates.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Exhaustive behavioral coverage for [EditorController] - the document owner
/// that funnels every mutation through the coalescing undo/redo history (#20).
/// Each test seeds a document via [loadProject], drives the controller, and
/// asserts against the freshly read [EditorState]. Assertions prefer invariants
/// (identity/equality, id relationships, monotonic history) over magic numbers;
/// the few hard-coded numbers (canvas center, cascade offset,
/// [EditorController.duplicateNudge]) are unambiguous from the source.
void main() {
  // The controller builds dart:ui value types (Offset/Rect/Color); a binding is
  // cheap insurance even though no widget tree is pumped.
  TestWidgetsFlutterBinding.ensureInitialized();

  // ---------------------------------------------------------------- helpers
  // 1080² is Project.empty's default canvas, so width/height are left implicit
  // to satisfy avoid_redundant_argument_values while keeping the intended size.
  Project defaultSeed() => Project.empty(id: 'p', createdAt: DateTime(2024));

  Project projectWith(
    List<Layer> layers, {
    int w = 1080,
    int h = 1080,
    int currentFrameIndex = 0,
  }) => Project(
    id: 'p',
    name: 'Untitled',
    canvasWidth: w,
    canvasHeight: h,
    currentFrameIndex: currentFrameIndex,
    frames: [Frame(id: 'p_f0', layers: layers)],
    createdAt: DateTime(2024),
  );

  // Multi-frame seed. Frame ids come from a loop variable so the invocation is
  // non-const (no prefer_const_constructors noise) and easy to reason about.
  Project framesSeed(List<String> ids, {int current = 0}) => Project(
    id: 'p',
    name: 'Untitled',
    canvasWidth: 1080,
    canvasHeight: 1080,
    currentFrameIndex: current,
    frames: [for (final id in ids) Frame(id: id)],
    createdAt: DateTime(2024),
  );

  ImageLayer img({
    required String id,
    String name = 'Photo',
    String assetPath = '/fake/a.png',
    Offset position = const Offset(540, 540),
    double scale = 1,
    String? maskPath,
    ImageAdjustments adjustments = ImageAdjustments.identity,
    Rect cropRect = const Rect.fromLTRB(0, 0, 1, 1),
    double outlineWidth = 0,
  }) => ImageLayer(
    id: id,
    name: name,
    assetPath: assetPath,
    transform: LayerTransform(position: position, scale: scale),
    maskPath: maskPath,
    adjustments: adjustments,
    cropRect: cropRect,
    outlineWidth: outlineWidth,
  );

  TextLayer txt({
    required String id,
    String name = 'Cap',
    String text = 'Cap',
    Offset position = const Offset(540, 540),
  }) => TextLayer(
    id: id,
    name: name,
    text: text,
    fontFamily: 'Bangers',
    transform: LayerTransform(position: position),
  );

  BubbleLayer bubble({
    required String id,
    String name = 'Hi',
    String text = 'Hi',
  }) => BubbleLayer(id: id, name: name, text: text);

  /// Opens a fresh container seeded with [seed] (or [defaultSeed]) and registers
  /// disposal. Returns the container + its controller.
  ({ProviderContainer container, EditorController controller}) open([
    Project? seed,
  ]) {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(editorControllerProvider.notifier);
    controller.loadProject(seed ?? defaultSeed());
    return (container: container, controller: controller);
  }

  EditorState read(ProviderContainer c) => c.read(editorControllerProvider);
  Layer byId(ProviderContainer c, String id) =>
      read(c).layers.firstWhere((l) => l.id == id);
  ImageLayer imageById(ProviderContainer c, String id) =>
      byId(c, id) as ImageLayer;

  // ---------------------------------------------------------------- add ops
  group('add ops', () {
    test(
      'addTextLayer appends a TextLayer at the canvas center and selects it',
      () {
        final (:container, :controller) = open();
        final layer = controller.addTextLayer();
        expect(read(container).layers, hasLength(1));
        expect(read(container).layers.single, same(layer));
        expect(layer.text, 'Text');
        expect(layer.name, 'Text'); // name mirrors the text
        expect(
          layer.transform.position,
          const Offset(540, 540),
        ); // canvasCenter
        expect(read(container).selectedLayerId, layer.id);
        expect(read(container).selectedLayer, layer);
      },
    );

    test(
      'addBubbleLayer names it "Bubble" when text is empty, else the text',
      () {
        final (:container, :controller) = open();
        final empty = controller.addBubbleLayer();
        expect(empty.name, 'Bubble');
        expect(empty.text, isEmpty);
        // Centered a little above the canvas middle (canvasCenter - (0, 36)).
        expect(empty.transform.position, const Offset(540, 504));
        expect(read(container).selectedLayerId, empty.id);

        final withText = controller.addBubbleLayer(text: 'Pow');
        expect(withText.name, 'Pow');
        expect(read(container).selectedLayerId, withText.id);
      },
    );

    test(
      'addImageLayer auto-numbers photos and cascade-offsets each new one',
      () {
        final (:container, :controller) = open();
        final p1 = controller.addImageLayer(assetPath: '/fake/a.png');
        expect(p1.name, 'Photo');
        expect(p1.assetPath, '/fake/a.png');
        expect(p1.transform.position, const Offset(540, 540)); // no cascade yet
        expect(read(container).selectedLayerId, p1.id);

        final p2 = controller.addImageLayer(assetPath: '/fake/b.png');
        expect(p2.name, 'Photo 2');
        // Second photo cascades 24 logical px (one existing photo * 24).
        expect(p2.transform.position, const Offset(564, 564));
        expect(read(container).selectedLayerId, p2.id);

        final named = controller.addImageLayer(
          assetPath: '/fake/c.png',
          name: 'Hero',
        );
        expect(named.name, 'Hero'); // explicit name skips auto-numbering
      },
    );

    test(
      'addEmoji drops a decorative (Rubik) text layer, centered and selected',
      () {
        final (:container, :controller) = open();
        final e = controller.addEmoji('😀');
        expect(e.decorative, isTrue);
        expect(e.fontFamily, 'Rubik');
        expect(e.text, '😀');
        expect(e.name, '😀');
        expect(e.transform.position, const Offset(540, 540));
        expect(read(container).selectedLayerId, e.id);
      },
    );
  });

  // -------------------------------------------------------------- layer ops
  group('layer ops', () {
    test('removeLayer deselects only when the removed layer was selected', () {
      final (:container, :controller) = open(
        projectWith([txt(id: 'l_0'), txt(id: 'l_1')]),
      );
      controller.selectLayer('l_1');
      controller.removeLayer('l_0'); // not the selected one
      expect(read(container).layers, hasLength(1));
      expect(read(container).selectedLayerId, 'l_1'); // selection preserved

      controller.removeLayer('l_1'); // the selected one
      expect(read(container).layers, isEmpty);
      expect(read(container).selectedLayerId, isNull);
    });

    test(
      'duplicateLayer inserts a nudged fresh-id copy at index+1 and selects it',
      () {
        final (:container, :controller) = open(
          projectWith([txt(id: 'l_0', position: const Offset(100, 100))]),
        );
        controller.duplicateLayer('l_0');
        final layers = read(container).layers;
        expect(layers, hasLength(2));
        final copy = layers[1]; // directly above the source
        expect(copy.id, isNot('l_0')); // fresh id
        expect(copy.name, 'Cap'); // content otherwise cloned
        // Nudged by duplicateNudge (16) on both axes from the source position.
        expect(
          copy.transform.position,
          const Offset(100, 100).translate(
            EditorController.duplicateNudge,
            EditorController.duplicateNudge,
          ),
        );
        expect(read(container).selectedLayerId, copy.id);
      },
    );

    test('duplicateLayer is a no-op for a missing id', () {
      final (:container, :controller) = open(projectWith([txt(id: 'l_0')]));
      controller.duplicateLayer('nope');
      expect(read(container).layers, hasLength(1));
    });

    test('reorderLayer clamps an out-of-range newIndex to the list end', () {
      final (:container, :controller) = open(
        projectWith([txt(id: 'l_0'), txt(id: 'l_1'), txt(id: 'l_2')]),
      );
      controller.reorderLayer(0, 99); // clamps to the tail
      expect(read(container).layers.map((l) => l.id), ['l_1', 'l_2', 'l_0']);
    });

    test('reorderLayer moves an item to an in-range slot', () {
      final (:container, :controller) = open(
        projectWith([txt(id: 'l_0'), txt(id: 'l_1'), txt(id: 'l_2')]),
      );
      controller.reorderLayer(2, 0);
      expect(read(container).layers.map((l) => l.id), ['l_2', 'l_0', 'l_1']);
    });

    test('toggleVisibility flips the layer visibility', () {
      final (:container, :controller) = open(projectWith([txt(id: 'l_0')]));
      expect(byId(container, 'l_0').visible, isTrue);
      controller.toggleVisibility('l_0');
      expect(byId(container, 'l_0').visible, isFalse);
      controller.toggleVisibility('l_0');
      expect(byId(container, 'l_0').visible, isTrue);
    });

    test('setOpacity sets exactly the requested opacity', () {
      final (:container, :controller) = open(projectWith([txt(id: 'l_0')]));
      controller.setOpacity('l_0', 0.25);
      expect(byId(container, 'l_0').opacity, 0.25);
    });

    test('updateTransform replaces the whole transform', () {
      final (:container, :controller) = open(projectWith([txt(id: 'l_0')]));
      const t = LayerTransform(
        position: Offset(10, 20),
        scale: 3,
        rotation: 1.5,
      );
      controller.updateTransform('l_0', t);
      expect(byId(container, 'l_0').transform, t);
    });

    test('renameLayer sets the name without touching other fields', () {
      final (:container, :controller) = open(
        projectWith([txt(id: 'l_0', name: 'Old')]),
      );
      controller.renameLayer('l_0', 'New');
      final l = byId(container, 'l_0') as TextLayer;
      expect(l.name, 'New');
      expect(l.text, 'Cap'); // text is independent of the layer name
    });
  });

  // ---------------------------------------------------------- image ops
  group('image layer ops', () {
    // A seed with an image layer carrying non-default transform/mask/crop/adjust
    // plus a text layer that every image op must leave untouched.
    ImageLayer seedImage() => img(
      id: 'l_0',
      position: const Offset(300, 400),
      scale: 2,
      maskPath: '/fake/mask.png',
      adjustments: const ImageAdjustments(brightness: 1.2),
      cropRect: const Rect.fromLTRB(0.1, 0.1, 0.9, 0.9),
    );
    final other = txt(id: 'l_1');

    test('updateImageAdjustments swaps only the adjustments', () {
      final base = seedImage();
      final (:container, :controller) = open(projectWith([base, other]));
      const adj = ImageAdjustments(
        brightness: 0.5,
        contrast: 1.5,
        saturation: 0.8,
        hue: 30,
      );
      controller.updateImageAdjustments('l_0', adj);
      final l = imageById(container, 'l_0');
      expect(l.adjustments, adj);
      expect(l.assetPath, base.assetPath); // everything else intact
      expect(l.transform, base.transform);
      expect(byId(container, 'l_1'), other); // text layer untouched
    });

    test('updateImageOutline sets width and color, and each independently', () {
      final (:container, :controller) = open(projectWith([seedImage()]));
      controller.updateImageOutline(
        'l_0',
        width: 4,
        color: const Color(0xFF00FF00),
      );
      var l = imageById(container, 'l_0');
      expect(l.outlineWidth, 4);
      expect(l.outlineColor, const Color(0xFF00FF00));
      expect(l.hasOutline, isTrue);

      // Color-only tick keeps the width; width-only tick keeps the color.
      controller.updateImageOutline('l_0', color: const Color(0xFF0000FF));
      l = imageById(container, 'l_0');
      expect(l.outlineWidth, 4);
      expect(l.outlineColor, const Color(0xFF0000FF));

      controller.updateImageOutline('l_0', width: 9);
      l = imageById(container, 'l_0');
      expect(l.outlineWidth, 9);
      expect(l.outlineColor, const Color(0xFF0000FF));
    });

    test('setImageMask sets a path and clears with null', () {
      final (:container, :controller) = open(projectWith([seedImage()]));
      controller.setImageMask('l_0', '/fake/new.png');
      expect(imageById(container, 'l_0').maskPath, '/fake/new.png');
      controller.setImageMask('l_0', null); // clearMask
      expect(imageById(container, 'l_0').maskPath, isNull);
    });

    test('setImageCrop stores the crop rect', () {
      final (:container, :controller) = open(projectWith([seedImage()]));
      const crop = Rect.fromLTRB(0.2, 0.2, 0.8, 0.8);
      controller.setImageCrop('l_0', crop);
      final l = imageById(container, 'l_0');
      expect(l.cropRect, crop);
      expect(l.isCropped, isTrue);
    });

    test(
      'replaceImageAsset swaps the path but keeps transform/mask/crop/adjust',
      () {
        final base = seedImage();
        final (:container, :controller) = open(projectWith([base, other]));
        controller.replaceImageAsset('l_0', '/fake/b.png');
        final l = imageById(container, 'l_0');
        expect(l.assetPath, '/fake/b.png');
        expect(l.transform, base.transform);
        expect(l.maskPath, base.maskPath);
        expect(l.cropRect, base.cropRect);
        expect(l.adjustments, base.adjustments);
        expect(byId(container, 'l_1'), other); // other layer types untouched
      },
    );
  });

  // ------------------------------------------------------- text & bubble
  group('text & bubble updates', () {
    test('updateTextLayer mirrors the layer name to the new text', () {
      final (:container, :controller) = open(
        projectWith([txt(id: 'l_0', name: 'Old', text: 'Old')]),
      );
      controller.updateTextLayer('l_0', text: 'Hello');
      final l = byId(container, 'l_0') as TextLayer;
      expect(l.text, 'Hello');
      expect(l.name, 'Hello');
    });

    test('updateBubbleLayer renames on non-blank text but never to blank', () {
      final (:container, :controller) = open(projectWith([bubble(id: 'l_0')]));
      controller.updateBubbleLayer('l_0', text: 'Yo');
      var b = byId(container, 'l_0') as BubbleLayer;
      expect(b.text, 'Yo');
      expect(b.name, 'Yo');

      controller.updateBubbleLayer('l_0', text: ''); // caption cleared
      b = byId(container, 'l_0') as BubbleLayer;
      expect(b.text, isEmpty); // the text does clear
      expect(b.name, 'Yo'); // but the name keeps the last non-empty value
    });
  });

  // --------------------------------------------------------- tool/selection
  group('tool & selection', () {
    test('setTool switches the active tool and breaks coalescing', () {
      final (:container, :controller) = open(projectWith([txt(id: 'l_0')]));
      controller.setOpacity('l_0', 0.8); // opens an opacity coalesce group
      controller.setTool(EditorTool.text); // resets the coalesce key
      expect(read(container).tool, EditorTool.text);
      controller.setOpacity('l_0', 0.5); // no longer coalesces -> new step

      controller.undo(); // undoes only the second opacity edit
      expect(byId(container, 'l_0').opacity, 0.8);
      controller.undo(); // undoes the first
      expect(byId(container, 'l_0').opacity, 1.0);
    });

    test('selectLayer(null) clears the selection', () {
      final (:container, :controller) = open(projectWith([txt(id: 'l_0')]));
      controller.selectLayer('l_0');
      expect(read(container).selectedLayer, isNotNull);
      controller.selectLayer(null);
      expect(read(container).selectedLayerId, isNull);
      expect(read(container).selectedLayer, isNull);
    });
  });

  // ------------------------------------------------------------ undo/redo
  group('undo / redo & history', () {
    test('canUndo / canRedo track the history transitions', () {
      final controller = open().controller;
      expect(controller.canUndo, isFalse);
      expect(controller.canRedo, isFalse);
      controller.addTextLayer();
      expect(controller.canUndo, isTrue);
      expect(controller.canRedo, isFalse);
      controller.undo();
      expect(controller.canUndo, isFalse);
      expect(controller.canRedo, isTrue);
      controller.redo();
      expect(controller.canUndo, isTrue);
      expect(controller.canRedo, isFalse);
    });

    test('two edits sharing a coalesce key fold into a single undo step', () {
      final (:container, :controller) = open(projectWith([txt(id: 'l_0')]));
      controller.setOpacity('l_0', 0.8);
      controller.setOpacity('l_0', 0.5); // same 'opacity:l_0' key -> folds
      expect(controller.canUndo, isTrue);
      controller.undo(); // one step returns to the pre-edit state
      expect(controller.canUndo, isFalse);
      expect(byId(container, 'l_0').opacity, 1.0);
    });

    test('endEdit resets the coalesce key so the next edit is a new step', () {
      final (:container, :controller) = open(projectWith([txt(id: 'l_0')]));
      controller.setOpacity('l_0', 0.8);
      controller.endEdit();
      controller.setOpacity('l_0', 0.5); // fresh key -> a distinct step
      controller.undo();
      expect(byId(container, 'l_0').opacity, 0.8);
      controller.undo();
      expect(byId(container, 'l_0').opacity, 1.0);
      expect(controller.canUndo, isFalse);
    });

    test(
      'history is capped at 50 steps (51 distinct commits -> 50 undoable)',
      () {
        final controller = open(projectWith([txt(id: 'l_0')])).controller;
        for (var i = 0; i < 51; i++) {
          controller.renameLayer('l_0', 'name$i'); // distinct, non-coalescing
        }
        var count = 0;
        while (controller.canUndo) {
          controller.undo();
          count++;
        }
        expect(count, 50);
      },
    );

    test('undo and redo both clear the selection', () {
      final (:container, :controller) = open();
      final a = controller.addTextLayer(); // undo=[loaded]
      final b = controller.addTextLayer(); // undo=[loaded, withA]
      expect(read(container).selectedLayerId, b.id);

      controller.undo(); // back to just A; selection cleared
      expect(read(container).selectedLayerId, isNull);

      controller.selectLayer(a.id); // re-select a layer that exists
      expect(read(container).selectedLayerId, a.id);
      controller.redo(); // re-adds B; selection cleared again
      expect(read(container).selectedLayerId, isNull);
    });

    test('a new commit clears the redo stack', () {
      final controller = open().controller;
      controller.addTextLayer();
      controller.undo();
      expect(controller.canRedo, isTrue);
      controller.addTextLayer(); // fresh commit
      expect(controller.canRedo, isFalse);
    });
  });

  // ---------------------------------------------------------- loadProject
  group('loadProject', () {
    test('resets undo/redo and coalescing', () {
      final controller = open().controller;
      controller.addTextLayer(); // build some history
      controller.undo();
      expect(controller.canRedo, isTrue);
      controller.loadProject(defaultSeed());
      expect(controller.canUndo, isFalse);
      expect(controller.canRedo, isFalse);
    });

    test(
      'bumps the id sequence past loaded ids so new layers never collide',
      () {
        final seed = Project(
          id: 'p',
          name: 'Untitled',
          canvasWidth: 1080,
          canvasHeight: 1080,
          frames: [
            Frame(
              id: 'f_5',
              layers: [txt(id: 'l_100', name: 't', text: 't')],
            ),
          ],
          createdAt: DateTime(2024),
        );
        final controller = open(seed).controller;
        final added = controller.addTextLayer();
        // seq bumped past l_100 -> next 'l' id is l_101, not a re-used l_100.
        expect(added.id, 'l_101');
        expect(added.id, isNot('l_100'));
      },
    );
  });

  // ------------------------------------------------------------ canvas ops
  group('canvas ops', () {
    test('setCanvasSize is a no-op when the size is unchanged', () {
      final controller = open(projectWith([img(id: 'l_0')])).controller;
      expect(controller.canUndo, isFalse);
      controller.setCanvasSize(1080, 1080);
      expect(controller.canUndo, isFalse); // no commit recorded
    });

    test('setCanvasSize without scaleContent resizes only the canvas', () {
      final (:container, :controller) = open(
        projectWith([
          img(id: 'l_0', position: const Offset(100, 200), scale: 2),
        ]),
      );
      controller.setCanvasSize(800, 600);
      expect(read(container).project.canvasWidth, 800);
      expect(read(container).project.canvasHeight, 600);
      final l = imageById(container, 'l_0');
      expect(l.transform.position, const Offset(100, 200)); // layers stay put
      expect(l.transform.scale, 2);
    });

    test(
      'setCanvasSize with scaleContent scales positions by sx/sy and scale by (sx+sy)/2',
      () {
        final (:container, :controller) = open(
          projectWith([
            img(id: 'l_0', position: const Offset(100, 200), scale: 2),
          ]),
        );
        // 1080->2160 (sx=2), 1080->540 (sy=0.5); layerScale=(2+0.5)/2=1.25.
        controller.setCanvasSize(2160, 540, scaleContent: true);
        expect(read(container).project.canvasWidth, 2160);
        expect(read(container).project.canvasHeight, 540);
        final l = imageById(container, 'l_0');
        expect(
          l.transform.position,
          const Offset(200, 100),
        ); // (100*2, 200*0.5)
        expect(l.transform.scale, 2.5); // 2 * 1.25
      },
    );

    test('setCanvasSize clamps dimensions to the project bounds', () {
      final (:container, :controller) = open(projectWith([img(id: 'l_0')]));
      controller.setCanvasSize(5, 999999);
      expect(read(container).project.canvasWidth, Project.minCanvasDimension);
      expect(read(container).project.canvasHeight, Project.maxCanvasDimension);
    });

    test('cropCanvas shifts layers by half the size delta (center crop)', () {
      final (:container, :controller) = open(projectWith([img(id: 'l_0')]));
      controller.cropCanvas(
        500,
        500,
      ); // shift = ((500-1080)/2) = -290 each axis
      expect(read(container).project.canvasWidth, 500);
      expect(read(container).project.canvasHeight, 500);
      // Source centered at (540, 540) -> (540-290, 540-290).
      expect(
        imageById(container, 'l_0').transform.position,
        const Offset(250, 250),
      );
    });

    test('cropCanvas is a no-op when the size is unchanged', () {
      final controller = open(projectWith([img(id: 'l_0')])).controller;
      controller.cropCanvas(1080, 1080);
      expect(controller.canUndo, isFalse);
    });

    test(
      'cropCanvasRect resizes to rect.size and shifts layers by -rect.topLeft',
      () {
        final (:container, :controller) = open(projectWith([img(id: 'l_0')]));
        controller.cropCanvasRect(const Rect.fromLTWH(100, 50, 400, 300));
        expect(read(container).project.canvasWidth, 400);
        expect(read(container).project.canvasHeight, 300);
        // Retained content keeps its place: (540-100, 540-50).
        expect(
          imageById(container, 'l_0').transform.position,
          const Offset(440, 490),
        );
      },
    );

    test('cropCanvasRect is a no-op for the identity rect', () {
      final controller = open(projectWith([img(id: 'l_0')])).controller;
      controller.cropCanvasRect(const Rect.fromLTWH(0, 0, 1080, 1080));
      expect(controller.canUndo, isFalse);
    });
  });

  // ------------------------------------------------------------- frame ops
  group('frame ops', () {
    test(
      'addFrame clones the current frame with fresh layer ids and selects it',
      () {
        final (:container, :controller) = open();
        final photo = controller.addImageLayer(assetPath: '/fake/a.png');
        controller.addFrame();
        final st = read(container);
        expect(st.project.frameCount, 2);
        expect(st.project.currentFrameIndex, 1); // the new frame is selected
        expect(st.selectedLayerId, isNull); // layer selection cleared
        final clonedLayers = st.project.frames[1].layers;
        expect(clonedLayers, hasLength(1));
        expect(clonedLayers.single.id, isNot(photo.id)); // fresh id
        expect(clonedLayers.single.name, photo.name); // same content
      },
    );

    test('deleteFrame keeps at least one frame', () {
      final (:container, :controller) = open(); // single-frame seed
      controller.deleteFrame(0);
      expect(read(container).project.frameCount, 1);
      expect(controller.canUndo, isFalse); // nothing recorded
    });

    test(
      'deleteFrame adjusts the current index when an earlier frame is removed',
      () {
        final (:container, :controller) = open(
          framesSeed(['f_0', 'f_1', 'f_2'], current: 2),
        );
        controller.deleteFrame(
          0,
        ); // removing a frame before current shifts left
        final st = read(container);
        expect(st.project.frames.map((f) => f.id), ['f_1', 'f_2']);
        expect(st.project.currentFrameIndex, 1); // still viewing f_2
      },
    );

    test(
      'duplicateFrame inserts a fresh-id copy after the source and selects it',
      () {
        final (:container, :controller) = open();
        final photo = controller.addImageLayer(assetPath: '/fake/a.png');
        controller.duplicateFrame(0);
        final st = read(container);
        expect(st.project.frameCount, 2);
        expect(st.project.currentFrameIndex, 1);
        expect(st.project.frames[1].layers.single.id, isNot(photo.id));
      },
    );

    test('reorderFrame moves a frame and keeps the viewed frame selected', () {
      final (:container, :controller) = open(
        framesSeed(['f_0', 'f_1', 'f_2'], current: 1), // viewing f_1
      );
      controller.reorderFrame(0, 2); // move f_0 to the tail
      final st = read(container);
      expect(st.project.frames.map((f) => f.id), ['f_1', 'f_2', 'f_0']);
      expect(st.project.currentFrameIndex, 0); // index follows f_1
    });

    test('reorderFrame ignores out-of-range or no-op moves', () {
      final (:container, :controller) = open(framesSeed(['f_0', 'f_1']));
      controller.reorderFrame(5, 0); // oldIndex out of range
      controller.reorderFrame(1, 1); // target == old
      expect(read(container).project.frames.map((f) => f.id), ['f_0', 'f_1']);
      expect(controller.canUndo, isFalse); // neither recorded a step
    });

    test('selectFrame is bounds-guarded and NOT undoable', () {
      final (:container, :controller) = open(framesSeed(['f_0', 'f_1', 'f_2']));
      controller.selectFrame(-1); // ignored
      controller.selectFrame(3); // ignored
      expect(read(container).project.currentFrameIndex, 0);
      controller.selectFrame(2); // valid
      expect(read(container).project.currentFrameIndex, 2);
      expect(controller.canUndo, isFalse); // frame nav is not a document edit
    });
  });

  // -------------------------------------------------------- isMaskReferenced
  group('isMaskReferenced', () {
    Project maskedSeed() => Project(
      id: 'm',
      name: 'M',
      canvasWidth: 1080,
      canvasHeight: 1080,
      frames: [
        Frame(
          id: 'm_f0',
          layers: [img(id: 'l_0', maskPath: 'mask.png')],
        ),
      ],
      createdAt: DateTime(2024),
    );

    test('is true for the live doc and false for an unrelated path', () {
      final controller = open(maskedSeed()).controller;
      expect(controller.isMaskReferenced('mask.png'), isTrue);
      expect(controller.isMaskReferenced('nope.png'), isFalse);
    });

    test('stays true while a dropped mask lives in an undo snapshot', () {
      final controller = open(maskedSeed()).controller;
      controller.setImageMask('l_0', null); // live drops the mask
      expect(controller.isMaskReferenced('mask.png'), isTrue); // still in undo
    });

    test('is true when the mask only lives in a redo snapshot', () {
      final base = Project(
        id: 'b',
        name: 'B',
        canvasWidth: 1080,
        canvasHeight: 1080,
        frames: [
          Frame(
            id: 'b_f0',
            layers: [img(id: 'l_0')],
          ),
        ],
        createdAt: DateTime(2024),
      );
      final controller = open(base).controller;
      controller.setImageMask('l_0', 'mask.png'); // live gains the mask
      controller.undo(); // live drops it; the masked doc moves to redo
      expect(controller.canUndo, isFalse);
      expect(controller.canRedo, isTrue);
      expect(controller.isMaskReferenced('mask.png'), isTrue); // via redo
    });

    test('ages out of history once its snapshot falls off the 50-step cap', () {
      final controller = open(maskedSeed()).controller;
      controller.setImageMask('l_0', null); // undo=[maskedDoc]
      // 49 further distinct commits: undo grows to 50, maskedDoc still at head.
      for (var i = 0; i < 49; i++) {
        controller.renameLayer('l_0', 'r$i');
      }
      expect(controller.isMaskReferenced('mask.png'), isTrue);
      controller.renameLayer('l_0', 'final'); // 50th -> maskedDoc drops off
      expect(controller.isMaskReferenced('mask.png'), isFalse);
    });
  });

  // ------------------------------------------------------------- photo grid
  group('addPhotoToCell', () {
    // Two equal columns over a 1080² canvas with the default 12px gap/margin:
    // c0 spans x 12..528, c1 spans x 552..1068, both y 12..1068.
    GridSpec twoColumns() => GridSpec(
      root: GridSplit(
        GridAxis.columns,
        [1, 1],
        const [GridLeaf('a'), GridLeaf('b')],
      ).withCanonicalIds(),
    );

    Project collageSeed() => Project.empty(
      id: 'p',
      createdAt: DateTime(2024),
    ).copyWith(grid: twoColumns());

    test('centres the photo on its cell and cover-scales it', () {
      final (:container, :controller) = open(collageSeed());
      final cell = layoutGrid(
        twoColumns(),
        const Size(1080, 1080),
      ).cells['c1']!;

      final layer = controller.addPhotoToCell(
        assetPath: '/fake/a.png',
        cellId: 'c1',
        pixels: const Size(2000, 1000),
      );

      expect(layer, isNotNull);
      expect(layer!.cellId, 'c1');
      expect(layer.transform.position, cell.center);
      // Cover, not contain: the photo fills the cell and the clip hides the
      // spill, so the scale matches photoCoverScale for that cell.
      expect(
        layer.transform.scale,
        photoCoverScale(const Size(2000, 1000), cell.width, cell.height),
      );
      // A cover scale really does overflow the cell on the long axis.
      expect(layer.transform.scale, greaterThan(1));
      expect(read(container).selectedLayerId, layer.id);
    });

    test('is one undoable step', () {
      final (:container, :controller) = open(collageSeed());
      controller.addPhotoToCell(assetPath: '/fake/a.png', cellId: 'c0');
      expect(read(container).layers, hasLength(1));
      controller.undo();
      expect(read(container).layers, isEmpty);
    });

    test('without pixel dimensions the photo lands unscaled', () {
      // The caller could not read the source size - leave it as imported
      // rather than guessing a scale.
      final (:container, :controller) = open(collageSeed());
      final layer = controller.addPhotoToCell(
        assetPath: '/fake/a.png',
        cellId: 'c0',
      );
      expect(layer!.transform.scale, 1);
    });

    test('refuses a project with no grid, or a cell the grid lacks', () {
      final (:container, :controller) = open(defaultSeed());
      expect(
        controller.addPhotoToCell(assetPath: '/fake/a.png', cellId: 'c0'),
        isNull,
      );
      expect(read(container).layers, isEmpty);

      controller.loadProject(collageSeed());
      expect(
        controller.addPhotoToCell(assetPath: '/fake/a.png', cellId: 'c9'),
        isNull,
      );
      expect(read(container).layers, isEmpty);
    });

    test('photos auto-number across cells', () {
      final (:container, :controller) = open(collageSeed());
      controller.addPhotoToCell(assetPath: '/fake/a.png', cellId: 'c0');
      controller.addPhotoToCell(assetPath: '/fake/b.png', cellId: 'c1');
      expect(read(container).layers.map((l) => l.name), ['Photo', 'Photo 2']);
    });
  });

  group('grid ops', () {
    Project collageSeed([int count = 2]) => Project.empty(
      id: 'p',
      createdAt: DateTime(2024),
    ).copyWith(grid: GridSpec(root: gridTemplatesFor(count).first.root));

    GridSpec gridOf(ProviderContainer c) => read(c).project.grid!;

    test('a collage opens on the Grid tool, an ordinary project does not', () {
      final (:container, :controller) = open(collageSeed());
      expect(read(container).tool, EditorTool.grid);
      controller.loadProject(defaultSeed());
      expect(read(container).tool, EditorTool.adjust);
    });

    test('setGridTemplate keeps photo N in cell N and re-fits it', () {
      final (:container, :controller) = open(collageSeed(3));
      for (final id in ['c0', 'c1', 'c2']) {
        controller.addPhotoToCell(assetPath: '/fake/$id.png', cellId: id);
      }
      final target = gridTemplatesFor(3)[2]; // big left + 2 stacked
      controller.setGridTemplate(target.root);

      expect(matchGridTemplate(gridOf(container).root)?.label, target.label);
      final rects = layoutGrid(gridOf(container), const Size(1080, 1080)).cells;
      for (final layer in read(container).layers) {
        expect(layer.transform.position, rects[layer.cellId]!.center);
      }
    });

    test('lowering the count drops the trailing photos in ONE undo step', () {
      final (:container, :controller) = open(collageSeed(4));
      for (final id in ['c0', 'c1', 'c2', 'c3']) {
        controller.addPhotoToCell(assetPath: '/fake/$id.png', cellId: id);
      }
      controller.setGridPhotoCount(2);

      expect(gridOf(container).cellCount, 2);
      expect(read(container).layers.map((l) => l.cellId), ['c0', 'c1']);
      // Undo restores both the layout and the dropped photos together.
      controller.undo();
      expect(gridOf(container).cellCount, 4);
      expect(read(container).layers, hasLength(4));
    });

    test('raising the count keeps every photo', () {
      final (:container, :controller) = open(collageSeed());
      controller.addPhotoToCell(assetPath: '/fake/a.png', cellId: 'c0');
      controller.setGridPhotoCount(5);
      expect(gridOf(container).cellCount, 5);
      expect(read(container).layers, hasLength(1));
    });

    test('the count clamps to the offered range and no-ops when unchanged', () {
      final (:container, :controller) = open(collageSeed());
      controller.setGridPhotoCount(99);
      expect(gridOf(container).cellCount, kMaxGridPhotos);
      final before = read(container).project;
      controller.setGridPhotoCount(kMaxGridPhotos);
      expect(read(container).project, same(before)); // no empty undo step
    });

    test('border edits coalesce per property and leave photos in place', () {
      final (:container, :controller) = open(collageSeed());
      final photo = controller.addPhotoToCell(
        assetPath: '/fake/a.png',
        cellId: 'c0',
      )!;

      for (final w in [20.0, 30.0, 40.0]) {
        controller.setGridBorder(width: w);
      }
      expect(gridOf(container).borderWidth, 40);
      // The outer frame tracks the gap.
      expect(gridOf(container).outerMargin, 40);
      // A slider drag is one undo step, and the photo has not moved.
      expect(byId(container, photo.id).transform, photo.transform);
      controller.undo();
      expect(gridOf(container).borderWidth, GridSpec.defaultBorderWidth);

      // A different property starts its own step rather than folding in.
      controller.setGridBorder(width: 30);
      controller.setGridBorder(color: const Color(0xFF112233));
      controller.undo();
      expect(gridOf(container).borderColor, const Color(0xFFFFFFFF));
      expect(gridOf(container).borderWidth, 30);
    });

    test('border values are clamped', () {
      final (:container, :controller) = open(collageSeed());
      controller.setGridBorder(width: 9999);
      expect(gridOf(container).borderWidth, GridSpec.maxBorderWidth);
      controller.setGridBorder(radius: -5);
      expect(gridOf(container).cornerRadius, 0);
    });

    test('shuffle rotates the photos one cell forward', () {
      final (:container, :controller) = open(collageSeed(3));
      for (final id in ['c0', 'c1', 'c2']) {
        controller.addPhotoToCell(assetPath: '/fake/$id.png', cellId: id);
      }
      controller.shuffleGridPhotos();
      expect(read(container).layers.map((l) => l.cellId), ['c1', 'c2', 'c0']);
      controller.undo();
      expect(read(container).layers.map((l) => l.cellId), ['c0', 'c1', 'c2']);
    });

    test('a divider drag resizes exactly two cells and is one undo step', () {
      final (:container, :controller) = open(collageSeed(3));
      for (final id in ['c0', 'c1', 'c2']) {
        controller.addPhotoToCell(assetPath: '/fake/$id.png', cellId: id);
      }
      const canvas = Size(1080, 1080);
      final before = layoutGrid(gridOf(container), canvas).cells;
      final divider = layoutGrid(gridOf(container), canvas).dividers.first;

      controller.beginDividerDrag();
      controller.dragDivider(divider, 60);
      controller.dragDivider(divider, 120); // same drag, absolute delta
      controller.endDividerDrag();

      final after = layoutGrid(gridOf(container), canvas).cells;
      expect(after['c0']!.width, greaterThan(before['c0']!.width));
      expect(after['c1']!.width, lessThan(before['c1']!.width));
      expect(after['c2'], before['c2']); // untouched by construction
      // The whole drag collapses into one history entry.
      controller.undo();
      expect(layoutGrid(gridOf(container), canvas).cells, before);
    });

    test('a drag maps from its start, so it never drifts', () {
      const canvas = Size(1080, 1080);
      Rect dragTo(double px, List<double> steps) {
        final (:container, :controller) = open(collageSeed());
        final divider = layoutGrid(gridOf(container), canvas).dividers.first;
        controller.beginDividerDrag();
        for (final step in steps) {
          controller.dragDivider(divider, step);
        }
        controller.dragDivider(divider, px);
        controller.endDividerDrag();
        return layoutGrid(gridOf(container), canvas).cells['c0']!;
      }

      // Many intermediate frames must land exactly where one jump does.
      expect(
        dragTo(100, const [10, 25, 40, 55, 70, 85]).width,
        closeTo(dragTo(100, const []).width, 1e-9),
      );
    });

    test('a drag carries the cells photos with them', () {
      final (:container, :controller) = open(collageSeed());
      final photo = controller.addPhotoToCell(
        assetPath: '/fake/a.png',
        cellId: 'c0',
        pixels: const Size(1000, 1000),
      )!;
      const canvas = Size(1080, 1080);
      final divider = layoutGrid(gridOf(container), canvas).dividers.first;

      controller.beginDividerDrag();
      controller.dragDivider(divider, 200);
      controller.endDividerDrag();

      final moved = byId(container, photo.id);
      final cell = layoutGrid(gridOf(container), canvas).cells['c0']!;
      expect(moved.transform.position, cell.center);
      // The cell grew, so the photo grew with it and still covers.
      expect(moved.transform.scale, greaterThan(photo.transform.scale));
    });

    test('grid ops are inert on a project without a grid', () {
      final (:container, :controller) = open(defaultSeed());
      final before = read(container).project;
      controller
        ..setGridPhotoCount(4)
        ..setGridTemplate(gridTemplatesFor(3).first.root)
        ..setGridBorder(width: 40)
        ..shuffleGridPhotos();
      expect(read(container).project, same(before));
      expect(controller.canUndo, isFalse);
    });
  });
}
