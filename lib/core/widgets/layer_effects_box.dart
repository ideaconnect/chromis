/// Widget-side twins of `layer_effects_painter.dart`: blend mode, layer
/// opacity and the drop shadow, applied to an arbitrary child.
///
/// Both are written as raw [RenderProxyBox]es issuing `saveLayer` on the
/// current canvas rather than as compositions of `Opacity` / `ColorFiltered` /
/// `ImageFiltered`. That is not a micro-optimisation - it is the only way this
/// can work. A blend mode has no representation in the engine's layer tree
/// (there is no `pushBlend`), so it MUST live inside a single recorded picture;
/// and every one of those wrapper widgets pushes a real compositing layer,
/// which would split the picture in half and orphan the enclosing `saveLayer`.
///
/// The corollary is a constraint on what may sit below one of these: the child
/// subtree must paint inline. The layer contents do (images, text, custom
/// painters, transforms), and [debugAssertPaintsInline] fails loudly in debug
/// if that ever stops being true - in release the effect degrades to "skipped"
/// rather than painting something wrong.
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../models/layer_effects.dart';
import '../rendering/layer_effects_painter.dart';

/// Composites its child as a group: [opacity] applied to the whole thing, then
/// blended onto what is already painted with [blend].
///
/// Mirrors the renderer's `saveLayer(blendMode + alpha)` around a layer.
class LayerBlendBox extends SingleChildRenderObjectWidget {
  const LayerBlendBox({
    super.key,
    required this.blend,
    required this.opacity,
    required super.child,
  });

  final LayerBlend blend;
  final double opacity;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderLayerBlend(blend, opacity);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderObject renderObject,
  ) {
    (renderObject as _RenderLayerBlend)
      ..blend = blend
      ..opacity = opacity;
  }
}

class _RenderLayerBlend extends RenderProxyBox {
  _RenderLayerBlend(this._blend, this._opacity);

  LayerBlend _blend;
  set blend(LayerBlend v) {
    if (v == _blend) return;
    _blend = v;
    markNeedsPaint();
  }

  double _opacity;
  set opacity(double v) {
    if (v == _opacity) return;
    _opacity = v;
    markNeedsPaint();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) return;
    final alpha = _opacity.clamp(0.0, 1.0);
    if (alpha <= 0) return;
    final grouped = !_blend.isNormal || alpha < 1;
    if (!grouped || !debugAssertPaintsInline(child, 'LayerBlendBox')) {
      super.paint(context, offset);
      return;
    }
    context.canvas.saveLayer(
      null,
      Paint()
        ..blendMode = _blend.mode
        ..color = Color.fromRGBO(0, 0, 0, alpha),
    );
    super.paint(context, offset);
    context.canvas.restore();
  }
}

/// Paints its child twice: once as a blurred, recoloured, offset silhouette
/// (the drop shadow) and once for real on top. [scale] is the canvas scale, so
/// a shadow authored in canvas-logical px lands the same size in a thumbnail,
/// on the editor canvas and in a 4K export.
class LayerShadowBox extends SingleChildRenderObjectWidget {
  const LayerShadowBox({
    super.key,
    required this.shadow,
    required this.scale,
    required super.child,
  });

  final LayerShadow shadow;
  final double scale;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderLayerShadow(shadow, scale);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderObject renderObject,
  ) {
    (renderObject as _RenderLayerShadow)
      ..shadow = shadow
      ..scale = scale;
  }
}

class _RenderLayerShadow extends RenderProxyBox {
  _RenderLayerShadow(this._shadow, this._scale);

  LayerShadow _shadow;
  set shadow(LayerShadow v) {
    if (v == _shadow) return;
    _shadow = v;
    markNeedsPaint();
  }

  double _scale;
  set scale(double v) {
    if (v == _scale) return;
    _scale = v;
    markNeedsPaint();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) return;
    if (!_shadow.isVisible ||
        !debugAssertPaintsInline(child, 'LayerShadowBox')) {
      super.paint(context, offset);
      return;
    }
    paintLayerShadow(
      context.canvas,
      _shadow,
      _scale,
      () => super.paint(context, offset),
    );
    super.paint(context, offset);
  }
}

/// Isolates [child] so blend modes inside it composite against the child's own
/// pixels and nothing else - without it, a Multiply layer over a transparent
/// part of the canvas would blend into the editor's backdrop, and the export
/// (which starts on transparency) would not match.
///
/// It has to be a raw `saveLayer`. The obvious alternative - wrapping the child
/// in an identity `ColorFiltered` to force a compositing layer - looks right
/// and does nothing: Skia folds away a no-op colour filter, the layer is never
/// created, and the blend quietly reaches the page again. The parity test with
/// a coloured backdrop is what caught that.
class CompositeGroup extends SingleChildRenderObjectWidget {
  const CompositeGroup({super.key, required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderCompositeGroup();
}

class _RenderCompositeGroup extends RenderProxyBox {
  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) return;
    if (!debugAssertPaintsInline(child, 'CompositeGroup')) {
      super.paint(context, offset);
      return;
    }
    // Unbounded: a layer's shadow or blur may reach past the canvas box, and a
    // bounded saveLayer would crop it before the enclosing clip gets to decide.
    context.canvas.saveLayer(null, Paint());
    super.paint(context, offset);
    context.canvas.restore();
  }
}

/// True when [child] can be painted into the caller's own `saveLayer`.
///
/// In debug this trips an assertion naming the offender, because a composited
/// descendant here does not produce a slightly-wrong picture - it produces an
/// unbalanced canvas. In release it simply reports false and the caller skips
/// the effect.
bool debugAssertPaintsInline(RenderObject child, String who) {
  if (!child.needsCompositing) return true;
  assert(
    false,
    '$who cannot group a child that needs compositing: ${child.runtimeType}. '
    'Layer content must paint inline (no Opacity / ColorFiltered / '
    'ImageFiltered / RepaintBoundary between the box and the content) - see '
    'the library doc in layer_effects_box.dart.',
  );
  return false;
}

/// The image filter a shadow uses, re-exported so callers of this library do
/// not have to reach into the painter as well.
ui.ImageFilter? layerShadowFilter(LayerShadow shadow, double scale) =>
    shadowImageFilter(shadow, scale);
