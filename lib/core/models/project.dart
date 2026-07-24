import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';

import 'frame.dart';
import 'grid.dart';

/// The top-level editor document: a variable-size canvas plus one or more
/// [frames], optionally partitioned into Photo Grid cells ([grid]). Serialized
/// as a versioned JSON manifest (see [schemaVersion]); image/mask bytes live
/// alongside it as project assets.
///
/// Layer transform positions are in **canvas pixel units** - the space
/// [canvasWidth] × [canvasHeight]. Legacy square projects (before variable
/// canvas sizes) migrate to [legacyCanvasSize]².
@immutable
class Project {
  const Project({
    required this.id,
    required this.name,
    required this.frames,
    this.canvasWidth = legacyCanvasSize,
    this.canvasHeight = legacyCanvasSize,
    this.currentFrameIndex = 0,
    this.fps = defaultFps,
    this.grid,
    this.createdAt,
    this.updatedAt,
  });

  /// Playback / export frame rate default.
  static const double defaultFps = 8;
  static const double minFps = 0.25;
  static const double maxFps = 30;

  /// On-disk manifest version. v1 = fixed 512² square; v2 = variable canvas;
  /// v3 = Photo Grid ([grid] + per-layer `cellId`).
  static const int schemaVersion = 3;

  /// The pre-variable-canvas square edge, used as the migration default for v1
  /// manifests and the fallback for any construction that omits a size.
  static const int legacyCanvasSize = 512;

  /// Default size for a new blank project (Instagram-square).
  static const int defaultCanvasWidth = 1080;
  static const int defaultCanvasHeight = 1080;

  /// Canvas bounds (px). Guards against absurd sizes that would OOM the GPU.
  static const int minCanvasDimension = 16;
  static const int maxCanvasDimension = 8192;

  final String id;
  final String name;
  final List<Frame> frames;

  /// Logical canvas size in pixels; also the layer-transform coordinate space.
  final int canvasWidth;
  final int canvasHeight;

  final int currentFrameIndex;
  final double fps;

  /// Photo Grid (collage) partition of the canvas, or null for an ordinary
  /// project. Layers reference its cells by `Layer.cellId`; the grid is
  /// project-level, so every frame shares it.
  final GridSpec? grid;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Whether this document is a Photo Grid (collage).
  bool get isGrid => grid != null;

  double get canvasAspect => canvasWidth / canvasHeight;

  /// Center of the canvas in logical units - where new layers are placed.
  Offset get canvasCenter => Offset(canvasWidth / 2, canvasHeight / 2);

  bool get isAnimated => frames.length > 1;
  int get frameCount => frames.length;

  int get safeFrameIndex =>
      frames.isEmpty ? 0 : currentFrameIndex.clamp(0, frames.length - 1);

  Frame get currentFrame => frames[safeFrameIndex];

  int get layerCount => frames.isEmpty ? 0 : currentFrame.layers.length;

  /// A new blank project with a single empty frame at the given canvas size.
  factory Project.empty({
    required String id,
    String name = 'Untitled',
    int width = defaultCanvasWidth,
    int height = defaultCanvasHeight,
    DateTime? createdAt,
  }) {
    return Project(
      id: id,
      name: name,
      frames: [Frame(id: '${id}_f0')],
      canvasWidth: width.clamp(minCanvasDimension, maxCanvasDimension),
      canvasHeight: height.clamp(minCanvasDimension, maxCanvasDimension),
      createdAt: createdAt,
      updatedAt: createdAt,
    );
  }

  Project copyWith({
    String? id,
    String? name,
    List<Frame>? frames,
    int? canvasWidth,
    int? canvasHeight,
    int? currentFrameIndex,
    double? fps,
    GridSpec? grid,
    bool clearGrid = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Project(
      id: id ?? this.id,
      name: name ?? this.name,
      frames: frames ?? this.frames,
      canvasWidth: canvasWidth ?? this.canvasWidth,
      canvasHeight: canvasHeight ?? this.canvasHeight,
      currentFrameIndex: currentFrameIndex ?? this.currentFrameIndex,
      fps: fps ?? this.fps,
      grid: clearGrid ? null : (grid ?? this.grid),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'version': schemaVersion,
    'id': id,
    'name': name,
    'canvasWidth': canvasWidth,
    'canvasHeight': canvasHeight,
    'currentFrameIndex': currentFrameIndex,
    'fps': fps,
    // Written only for collages, so ordinary manifests are byte-unchanged.
    if (grid != null) 'grid': grid!.toJson(),
    'createdAt': createdAt?.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
    'frames': frames.map((f) => f.toJson()).toList(),
  };

  factory Project.fromJson(Map<String, dynamic> json) {
    final version = json['version'] as int? ?? 1;
    if (version > schemaVersion) {
      throw FormatException(
        'Project manifest version $version is newer than supported '
        '$schemaVersion',
      );
    }
    // v1 manifests predate variable canvases - migrate to the legacy square.
    // v1/v2 predate Photo Grid, so `grid` is simply absent and reads as null.
    final grid = json['grid'];
    return Project(
      grid: grid == null
          ? null
          : GridSpec.fromJson((grid as Map).cast<String, dynamic>()),
      id: json['id'] as String,
      name: json['name'] as String,
      canvasWidth: json['canvasWidth'] as int? ?? legacyCanvasSize,
      canvasHeight: json['canvasHeight'] as int? ?? legacyCanvasSize,
      currentFrameIndex: json['currentFrameIndex'] as int? ?? 0,
      fps: ((json['fps'] as num?)?.toDouble() ?? defaultFps).clamp(
        minFps,
        maxFps,
      ),
      createdAt: _parseDate(json['createdAt']),
      updatedAt: _parseDate(json['updatedAt']),
      frames: (json['frames'] as List)
          .map((e) => Frame.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
    );
  }

  static DateTime? _parseDate(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;

  @override
  bool operator ==(Object other) =>
      other is Project &&
      other.id == id &&
      other.name == name &&
      other.canvasWidth == canvasWidth &&
      other.canvasHeight == canvasHeight &&
      other.currentFrameIndex == currentFrameIndex &&
      other.fps == fps &&
      other.grid == grid &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt &&
      listEquals(other.frames, frames);

  @override
  int get hashCode => Object.hash(
    id,
    name,
    canvasWidth,
    canvasHeight,
    currentFrameIndex,
    fps,
    grid,
    createdAt,
    updatedAt,
    Object.hashAll(frames),
  );
}
