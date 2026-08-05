/// Classical content-aware fill: PatchMatch (Barnes et al. 2009) driving the
/// coarse-to-fine patch voting of Wexler et al. 2007. Pure Dart, no model, no
/// network - the hole is rebuilt out of texture the photo already contains.
///
/// This is the ALWAYS-available fill tier. The optional MI-GAN model
/// (`inpaint_engine.dart`) hallucinates plausible new content and beats it on
/// structured scenes; this one only ever copies what is already in the frame,
/// which is exactly why it can ship unconditionally: nothing to download, no
/// licence to audit, and it degrades to a smear rather than to a wrong guess.
///
/// Everything here is byte-array in, byte-array out so it can run inside
/// `Isolate.run` and be unit-tested without decoding an image.
library;

import 'dart:math' as math;
import 'dart:typed_data';

/// Tuning for [contentAwareFill]. The defaults are sized for the ≤512 px
/// working window `ContentFillEngine` hands over, on a mid-range phone.
class PatchMatchOptions {
  const PatchMatchOptions({
    this.patchRadius = 3,
    this.iterations = 6,
    this.coarsestSide = 24,
    this.maxLevels = 6,
    this.seed = 0x5EED,
  });

  /// Half-width of the square patch; 3 means 7×7.
  final int patchRadius;

  /// EM sweeps at the COARSEST level. Every finer level runs one fewer (never
  /// below 2): its correspondence field is warm-started from the level above,
  /// so it converges in a couple of sweeps - and it is the expensive one.
  final int iterations;

  /// The pyramid stops once halving would take the short side below this.
  final int coarsestSide;

  /// Hard cap on pyramid depth, so a huge window cannot pay for 12 levels.
  final int maxLevels;

  /// Fixed, so a fill is reproducible - random search is the only stochastic
  /// step and a test could not assert on pixels otherwise.
  final int seed;
}

/// Fills every pixel of [rgb] where [hole] is non-zero with content synthesized
/// from the rest of the image, returning a new buffer ([rgb] is not mutated).
///
/// [rgb] is `width * height * 3` bytes (r,g,b interleaved, row-major); [hole] is
/// `width * height` bytes where non-zero means "synthesize me".
Uint8List contentAwareFill(
  Uint8List rgb,
  Uint8List hole,
  int width,
  int height, {
  PatchMatchOptions options = const PatchMatchOptions(),
}) {
  assert(rgb.length == width * height * 3, 'rgb must be width*height*3');
  assert(hole.length == width * height, 'hole must be width*height');
  final levels = _pyramid(rgb, hole, width, height, options);

  // Coarsest first. Level 0 is the working resolution and is what we return.
  Int32List? field;
  _Level? coarser;
  for (var i = levels.length - 1; i >= 0; i--) {
    final level = levels[i];
    if (coarser == null) {
      _onionFill(level);
    } else {
      _carryDown(coarser, level);
      field = _carryField(field!, coarser, level);
    }
    final sweeps = math.max(2, options.iterations - (levels.length - 1 - i));
    field = _solve(level, field, options, sweeps);
    coarser = level;
  }
  return levels.first.rgb;
}

/// `round().clamp(0, 255)` without the boxing - `clamp` is declared on `num`,
/// so its result is boxed even when every argument is an `int`. Called once per
/// channel per hole pixel per sweep, which is often enough to matter.
int _clamp255(double v) {
  final r = v.round();
  if (r < 0) return 0;
  if (r > 255) return 255;
  return r;
}

/// One rung of the image pyramid. [rgb] is mutated in place as the fill
/// converges; [hole] never changes.
final class _Level {
  _Level(this.rgb, this.hole, this.w, this.h);

  final Uint8List rgb;
  final Uint8List hole;
  final int w;
  final int h;
}

/// Fine (index 0) to coarse. Halving stops before the image gets smaller than a
/// patch, so every level can still run PatchMatch.
List<_Level> _pyramid(
  Uint8List rgb,
  Uint8List hole,
  int width,
  int height,
  PatchMatchOptions options,
) {
  final levels = <_Level>[_Level(Uint8List.fromList(rgb), hole, width, height)];
  final floor = math.max(options.coarsestSide, 2 * options.patchRadius + 1);
  while (levels.length < options.maxLevels) {
    final fine = levels.last;
    if (fine.w ~/ 2 < floor || fine.h ~/ 2 < floor) break;
    levels.add(_halve(fine));
  }
  return levels;
}

/// Box-halves a level. Colour averages only the KNOWN children, so the hole's
/// stale contents never bleed into the coarse image; the hole itself takes the
/// max (any child a hole ⇒ the parent is a hole), which grows it slightly and
/// keeps the coarse levels conservative. Finer levels re-impose the true
/// boundary anyway, since known pixels are never voted over.
_Level _halve(_Level src) {
  final w = src.w ~/ 2;
  final h = src.h ~/ 2;
  final rgb = Uint8List(w * h * 3);
  final hole = Uint8List(w * h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      var r = 0, g = 0, b = 0, known = 0, holed = 0;
      for (var dy = 0; dy < 2; dy++) {
        for (var dx = 0; dx < 2; dx++) {
          final s = (y * 2 + dy) * src.w + (x * 2 + dx);
          if (src.hole[s] != 0) {
            holed = 1;
            continue;
          }
          final o = s * 3;
          r += src.rgb[o];
          g += src.rgb[o + 1];
          b += src.rgb[o + 2];
          known++;
        }
      }
      final d = y * w + x;
      hole[d] = holed;
      if (known > 0) {
        rgb[d * 3] = r ~/ known;
        rgb[d * 3 + 1] = g ~/ known;
        rgb[d * 3 + 2] = b ~/ known;
      }
    }
  }
  return _Level(rgb, hole, w, h);
}

/// Seeds the coarsest level by peeling the hole inward: every unfilled pixel
/// touching a filled one takes the average of its filled 8-neighbours. The
/// result is a smear, not a fill - but PatchMatch needs SOMETHING in the hole to
/// compare patches against, and a smear that follows the surrounding colours is
/// a far better starting point than noise or grey.
void _onionFill(_Level l) {
  final n = l.w * l.h;
  final filled = Uint8List(n);
  final queue = Int32List(n);
  var tail = 0;
  for (var i = 0; i < n; i++) {
    if (l.hole[i] == 0) {
      filled[i] = 1;
      queue[tail++] = i;
    }
  }
  if (tail == 0 || tail == n) return; // all hole, or nothing to do
  for (var head = 0; head < tail; head++) {
    final p = queue[head];
    final px = p % l.w;
    final py = p ~/ l.w;
    for (var dy = -1; dy <= 1; dy++) {
      final qy = py + dy;
      if (qy < 0 || qy >= l.h) continue;
      for (var dx = -1; dx <= 1; dx++) {
        final qx = px + dx;
        if (qx < 0 || qx >= l.w) continue;
        final q = qy * l.w + qx;
        if (filled[q] != 0) continue;
        var r = 0, g = 0, b = 0, c = 0;
        for (var ey = -1; ey <= 1; ey++) {
          final ny = qy + ey;
          if (ny < 0 || ny >= l.h) continue;
          for (var ex = -1; ex <= 1; ex++) {
            final nx = qx + ex;
            if (nx < 0 || nx >= l.w) continue;
            final e = ny * l.w + nx;
            if (filled[e] == 0) continue;
            r += l.rgb[e * 3];
            g += l.rgb[e * 3 + 1];
            b += l.rgb[e * 3 + 2];
            c++;
          }
        }
        if (c == 0) continue;
        l.rgb[q * 3] = r ~/ c;
        l.rgb[q * 3 + 1] = g ~/ c;
        l.rgb[q * 3 + 2] = b ~/ c;
        filled[q] = 1;
        queue[tail++] = q;
      }
    }
  }
}

/// Bilinearly lifts the coarser level's converged colours into the finer
/// level's hole. Known pixels keep their TRUE values - only the hole is guessed.
void _carryDown(_Level coarse, _Level fine) {
  final sx = coarse.w / fine.w;
  final sy = coarse.h / fine.h;
  for (var y = 0; y < fine.h; y++) {
    final cy = ((y + 0.5) * sy - 0.5).clamp(0.0, coarse.h - 1.0);
    final y0 = cy.floor();
    final y1 = math.min(y0 + 1, coarse.h - 1);
    final fy = cy - y0;
    for (var x = 0; x < fine.w; x++) {
      final p = y * fine.w + x;
      if (fine.hole[p] == 0) continue;
      final cx = ((x + 0.5) * sx - 0.5).clamp(0.0, coarse.w - 1.0);
      final x0 = cx.floor();
      final x1 = math.min(x0 + 1, coarse.w - 1);
      final fx = cx - x0;
      for (var c = 0; c < 3; c++) {
        final v00 = coarse.rgb[(y0 * coarse.w + x0) * 3 + c].toDouble();
        final v10 = coarse.rgb[(y0 * coarse.w + x1) * 3 + c].toDouble();
        final v01 = coarse.rgb[(y1 * coarse.w + x0) * 3 + c].toDouble();
        final v11 = coarse.rgb[(y1 * coarse.w + x1) * 3 + c].toDouble();
        final top = v00 + (v10 - v00) * fx;
        final bottom = v01 + (v11 - v01) * fx;
        fine.rgb[p * 3 + c] = _clamp255(top + (bottom - top) * fy);
      }
    }
  }
}

/// Rescales the coarse correspondence field into the fine level's geometry, so
/// the finer solve starts from an answer instead of from noise. Offsets are
/// what scale (a match 4 coarse pixels left is 8 fine pixels left), not the
/// absolute source position. Entries are validated by [_solve].
Int32List _carryField(Int32List coarse, _Level c, _Level f) {
  final out = Int32List(f.w * f.h)..fillRange(0, f.w * f.h, -1);
  final sx = c.w / f.w;
  final sy = c.h / f.h;
  for (var y = 0; y < f.h; y++) {
    final cy = (y * sy).floor().clamp(0, c.h - 1);
    for (var x = 0; x < f.w; x++) {
      final cx = (x * sx).floor().clamp(0, c.w - 1);
      final s = coarse[cy * c.w + cx];
      if (s < 0) continue;
      final ox = ((s % c.w - cx) / sx).round();
      final oy = ((s ~/ c.w - cy) / sy).round();
      final tx = (x + ox).clamp(0, f.w - 1);
      final ty = (y + oy).clamp(0, f.h - 1);
      out[y * f.w + x] = ty * f.w + tx;
    }
  }
  return out;
}

/// Runs [sweeps] EM iterations on one level and returns its correspondence
/// field (source pixel index per target pixel, `-1` where undefined).
///
/// Target = every pixel whose patch touches the hole, not just hole pixels
/// themselves: a patch straddling the boundary is what ties the synthesized
/// content to the real content around it.
Int32List _solve(
  _Level l,
  Int32List? seed,
  PatchMatchOptions options,
  int sweeps,
) {
  final r = options.patchRadius;
  final w = l.w;
  final h = l.h;
  final n = w * h;
  final field = Int32List(n)..fillRange(0, n, -1);
  if (w < 2 * r + 1 || h < 2 * r + 1) return field;

  final sat = _holeSat(l);
  final sourceOk = _sourceCentres(sat, w, h, r);
  final target = _targets(sat, w, h, r);

  // Valid source centres, for the initial guess. None ⇒ the hole (grown by the
  // pyramid) swallowed this level; leave it to the finer levels, which have
  // proportionally more known pixels.
  final sources = <int>[];
  for (var i = 0; i < n; i++) {
    if (sourceOk[i] != 0) sources.add(i);
  }
  if (sources.isEmpty) return field;

  final rand = math.Random(options.seed);
  final dist = Int32List(n);
  for (var p = 0; p < n; p++) {
    if (target[p] == 0) continue;
    var s = seed == null ? -1 : seed[p];
    if (s < 0 || sourceOk[s] == 0) s = sources[rand.nextInt(sources.length)];
    field[p] = s;
    dist[p] = _patchDistance(
      l.rgb,
      w,
      h,
      p % w,
      p ~/ w,
      s % w,
      s ~/ w,
      r,
      0x7FFFFFFF,
    );
  }

  final best = _Best();
  for (var sweep = 0; sweep < sweeps; sweep++) {
    _sweep(l, target, sourceOk, field, dist, r, rand, best, sweep.isEven);
    _vote(l, field, dist, r);
  }
  return field;
}

/// Summed-area table of the hole, so "does this rect contain a hole pixel?" is
/// four lookups instead of a patch-sized scan - asked once per pixel for both
/// the source map and the target map.
Int32List _holeSat(_Level l) {
  final w = l.w;
  final h = l.h;
  final sat = Int32List((w + 1) * (h + 1));
  for (var y = 0; y < h; y++) {
    var row = 0;
    for (var x = 0; x < w; x++) {
      if (l.hole[y * w + x] != 0) row++;
      sat[(y + 1) * (w + 1) + x + 1] = sat[y * (w + 1) + x + 1] + row;
    }
  }
  return sat;
}

int _rectSum(Int32List sat, int w, int x0, int y0, int x1, int y1) =>
    sat[y1 * (w + 1) + x1] -
    sat[y0 * (w + 1) + x1] -
    sat[y1 * (w + 1) + x0] +
    sat[y0 * (w + 1) + x0];

/// Pixels whose whole patch is in-bounds AND hole-free: the only places a match
/// may come from. Sampling a patch that overlaps the hole would let the smear
/// reproduce itself.
Uint8List _sourceCentres(Int32List sat, int w, int h, int r) {
  final ok = Uint8List(w * h);
  for (var y = r; y < h - r; y++) {
    for (var x = r; x < w - r; x++) {
      if (_rectSum(sat, w, x - r, y - r, x + r + 1, y + r + 1) == 0) {
        ok[y * w + x] = 1;
      }
    }
  }
  return ok;
}

/// Pixels whose patch touches the hole (the hole dilated by [r]).
Uint8List _targets(Int32List sat, int w, int h, int r) {
  final out = Uint8List(w * h);
  for (var y = 0; y < h; y++) {
    final y0 = math.max(0, y - r);
    final y1 = math.min(h, y + r + 1);
    for (var x = 0; x < w; x++) {
      final x0 = math.max(0, x - r);
      final x1 = math.min(w, x + r + 1);
      if (_rectSum(sat, w, x0, y0, x1, y1) > 0) out[y * w + x] = 1;
    }
  }
  return out;
}

/// The running best match for one target pixel. A mutable holder rather than a
/// closure over locals: this is the hot loop, and captured mutable locals get
/// boxed.
final class _Best {
  int index = 0;
  int dist = 0;
}

/// One PatchMatch sweep: propagate a neighbour's match (patches that are
/// adjacent in the target are usually adjacent in the source too), then random
/// search at exponentially shrinking radius to escape local minima. Direction
/// alternates so information travels both ways across the hole.
void _sweep(
  _Level l,
  Uint8List target,
  Uint8List sourceOk,
  Int32List field,
  Int32List dist,
  int r,
  math.Random rand,
  _Best best,
  bool forward,
) {
  final w = l.w;
  final h = l.h;
  final n = w * h;
  final step = forward ? 1 : -1;
  final start = forward ? 0 : n - 1;
  final searchStart = math.max(w, h);
  for (var k = 0; k < n; k++) {
    final p = start + step * k;
    if (target[p] == 0) continue;
    final px = p % w;
    final py = p ~/ w;
    best.index = field[p];
    best.dist = dist[p];

    // Horizontal neighbour: its source, shifted by the same one pixel.
    final hx = px - step;
    if (hx >= 0 && hx < w) {
      final s = field[p - step];
      if (s >= 0) {
        _consider(best, l.rgb, sourceOk, w, h, px, py, s % w + step, s ~/ w, r);
      }
    }
    // Vertical neighbour, likewise.
    final vy = py - step;
    if (vy >= 0 && vy < h) {
      final s = field[p - step * w];
      if (s >= 0) {
        _consider(best, l.rgb, sourceOk, w, h, px, py, s % w, s ~/ w + step, r);
      }
    }

    var radius = searchStart;
    while (radius >= 1) {
      final bx = best.index % w;
      final by = best.index ~/ w;
      _consider(
        best,
        l.rgb,
        sourceOk,
        w,
        h,
        px,
        py,
        bx + rand.nextInt(2 * radius + 1) - radius,
        by + rand.nextInt(2 * radius + 1) - radius,
        r,
      );
      radius ~/= 2;
    }

    field[p] = best.index;
    dist[p] = best.dist;
  }
}

void _consider(
  _Best best,
  Uint8List rgb,
  Uint8List sourceOk,
  int w,
  int h,
  int px,
  int py,
  int sx,
  int sy,
  int r,
) {
  if (sx < r || sy < r || sx >= w - r || sy >= h - r) return;
  final s = sy * w + sx;
  if (sourceOk[s] == 0 || s == best.index) return;
  final d = _patchDistance(rgb, w, h, px, py, sx, sy, r, best.dist);
  if (d < best.dist) {
    best.index = s;
    best.dist = d;
  }
}

/// Sum of squared RGB differences between the patch at the target and the patch
/// at the source, bailing out as soon as it can no longer win - most candidates
/// are rejected in the first row or two, which is what makes the search
/// affordable. The target patch clamps at the border; the source never needs to
/// (only fully in-bounds centres are valid).
///
/// This is THE hot loop - it runs a few hundred thousand times per pyramid
/// level - so it is split in two. A target patch that is entirely inside the
/// image needs no clamping at all and walks both patches with a running offset;
/// only a patch hanging off an edge pays per-pixel bounds work. The border case
/// clamps with comparisons rather than `clamp()`, which is declared on `num`
/// and boxes its result: on device, that boxing was most of the fill's cost.
int _patchDistance(
  Uint8List rgb,
  int w,
  int h,
  int px,
  int py,
  int sx,
  int sy,
  int r,
  int cutoff,
) {
  var sum = 0;
  final span = 2 * r + 1;
  if (px >= r && py >= r && px + r < w && py + r < h) {
    for (var dy = -r; dy <= r; dy++) {
      var t = ((py + dy) * w + px - r) * 3;
      var s = ((sy + dy) * w + sx - r) * 3;
      for (var i = 0; i < span; i++) {
        final d0 = rgb[t] - rgb[s];
        final d1 = rgb[t + 1] - rgb[s + 1];
        final d2 = rgb[t + 2] - rgb[s + 2];
        sum += d0 * d0 + d1 * d1 + d2 * d2;
        t += 3;
        s += 3;
      }
      if (sum >= cutoff) return sum;
    }
    return sum;
  }
  for (var dy = -r; dy <= r; dy++) {
    var tyy = py + dy;
    if (tyy < 0) {
      tyy = 0;
    } else if (tyy >= h) {
      tyy = h - 1;
    }
    final ty = tyy * w;
    var s = ((sy + dy) * w + sx - r) * 3;
    for (var dx = -r; dx <= r; dx++) {
      var txx = px + dx;
      if (txx < 0) {
        txx = 0;
      } else if (txx >= w) {
        txx = w - 1;
      }
      final t = (ty + txx) * 3;
      final d0 = rgb[t] - rgb[s];
      final d1 = rgb[t + 1] - rgb[s + 1];
      final d2 = rgb[t + 2] - rgb[s + 2];
      sum += d0 * d0 + d1 * d1 + d2 * d2;
      s += 3;
    }
    if (sum >= cutoff) return sum;
  }
  return sum;
}

/// The M step: every hole pixel becomes the weighted average of the pixel each
/// overlapping target patch maps it to. Averaging over all ~(2r+1)² patches that
/// cover it - not just the one centred on it - is what makes the result
/// coherent instead of a mosaic of copied squares. Better matches weigh more,
/// so one bad correspondence cannot wash out a good neighbourhood.
void _vote(_Level l, Int32List field, Int32List dist, int r) {
  final w = l.w;
  final h = l.h;
  final n = w * h;
  final acc = Float32List(n * 3);
  final weights = Float32List(n);
  // An average per-channel error of ~10 halves a patch's vote.
  final sigma = (2 * r + 1) * (2 * r + 1) * 3 * 100.0;
  for (var q = 0; q < n; q++) {
    final s = field[q];
    if (s < 0) continue;
    final qx = q % w;
    final qy = q ~/ w;
    final sx = s % w;
    final sy = s ~/ w;
    final weight = 1.0 / (1.0 + dist[q] / sigma);
    for (var dy = -r; dy <= r; dy++) {
      final ty = qy + dy;
      if (ty < 0 || ty >= h) continue;
      final sourceRow = (sy + dy) * w;
      for (var dx = -r; dx <= r; dx++) {
        final tx = qx + dx;
        if (tx < 0 || tx >= w) continue;
        final t = ty * w + tx;
        if (l.hole[t] == 0) continue;
        final o = (sourceRow + sx + dx) * 3;
        acc[t * 3] += weight * l.rgb[o];
        acc[t * 3 + 1] += weight * l.rgb[o + 1];
        acc[t * 3 + 2] += weight * l.rgb[o + 2];
        weights[t] += weight;
      }
    }
  }
  for (var p = 0; p < n; p++) {
    if (l.hole[p] == 0 || weights[p] <= 0) continue;
    final inv = 1.0 / weights[p];
    l.rgb[p * 3] = _clamp255(acc[p * 3] * inv);
    l.rgb[p * 3 + 1] = _clamp255(acc[p * 3 + 1] * inv);
    l.rgb[p * 3 + 2] = _clamp255(acc[p * 3 + 2] * inv);
  }
}
