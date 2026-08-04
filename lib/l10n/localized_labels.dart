import '../core/models/layer_effects.dart';
import '../core/models/photo_filter.dart';
import '../features/editor/state/editor_tool.dart';
import '../features/editor/widgets/canvas_size_sheet.dart';
import '../features/grid/grid_templates.dart';
import '../features/segmentation/seg_model.dart';
import 'app_localizations.dart';

/// Display names for the app's enums and small registries.
///
/// The types themselves keep their English `label` field. That field is
/// identity as much as presentation - grid templates are matched and keyed by
/// it, a persisted project stores enum *names* beside it, and the tests read it
/// - so it stays a stable constant and the translation lives here, as a
/// separate lookup. Keeping every table in one file also means adding an enum
/// value is one compile error in one place rather than a silently untranslated
/// row.
///
/// The string-keyed lookups ([GridTemplateL10n], [CanvasPresetL10n]) fall
/// through to the English original for anything unmapped, so a new preset added
/// without a translation renders in English rather than blank.
extension EditorToolL10n on EditorTool {
  /// Short label under the icon in the dock / rail.
  String tabLabelOf(AppLocalizations l10n) => switch (this) {
    EditorTool.layers => l10n.toolLayers,
    EditorTool.adjust => l10n.toolAdjust,
    EditorTool.effects => l10n.toolEffects,
    EditorTool.text => l10n.toolText,
    EditorTool.erase => l10n.toolErase,
    EditorTool.cutout => l10n.toolCutout,
    EditorTool.frames => l10n.toolFrames,
    EditorTool.grid => l10n.toolGrid,
  };

  /// Longer title at the top of the tool's panel.
  String panelTitleOf(AppLocalizations l10n) => switch (this) {
    EditorTool.layers => l10n.toolLayers,
    EditorTool.adjust => l10n.toolAdjust,
    EditorTool.effects => l10n.toolEffects,
    EditorTool.text => l10n.toolText,
    EditorTool.erase => l10n.toolErasePanel,
    EditorTool.cutout => l10n.toolCutoutPanel,
    EditorTool.frames => l10n.toolFramesPanel,
    EditorTool.grid => l10n.toolGridPanel,
  };
}

extension PhotoFilterL10n on PhotoFilter {
  String labelOf(AppLocalizations l10n) => switch (this) {
    PhotoFilter.none => l10n.filterOriginal,
    PhotoFilter.vivid => l10n.filterVivid,
    PhotoFilter.punch => l10n.filterPunch,
    PhotoFilter.chrome => l10n.filterChrome,
    PhotoFilter.warm => l10n.filterWarm,
    PhotoFilter.cool => l10n.filterCool,
    PhotoFilter.sunset => l10n.filterSunset,
    PhotoFilter.dawn => l10n.filterDawn,
    PhotoFilter.dusk => l10n.filterDusk,
    PhotoFilter.fade => l10n.filterFade,
    PhotoFilter.matte => l10n.filterMatte,
    PhotoFilter.retro => l10n.filterRetro,
    PhotoFilter.sepia => l10n.filterSepia,
    PhotoFilter.mono => l10n.filterMono,
    PhotoFilter.noir => l10n.filterNoir,
  };
}

extension LayerBlendL10n on LayerBlend {
  String labelOf(AppLocalizations l10n) => switch (this) {
    LayerBlend.normal => l10n.blendNormal,
    LayerBlend.multiply => l10n.blendMultiply,
    LayerBlend.screen => l10n.blendScreen,
    LayerBlend.overlay => l10n.blendOverlay,
    LayerBlend.darken => l10n.blendDarken,
    LayerBlend.lighten => l10n.blendLighten,
    LayerBlend.colorDodge => l10n.blendDodge,
    LayerBlend.colorBurn => l10n.blendBurn,
    LayerBlend.hardLight => l10n.blendHardLight,
    LayerBlend.softLight => l10n.blendSoftLight,
    LayerBlend.difference => l10n.blendDifference,
    LayerBlend.exclusion => l10n.blendExclusion,
    LayerBlend.hue => l10n.blendHue,
    LayerBlend.saturation => l10n.blendSaturation,
    LayerBlend.color => l10n.blendColor,
    LayerBlend.luminosity => l10n.blendLuminosity,
  };
}

extension SegModelL10n on SegModel {
  /// "Built-in AI" is translated; "U²-Net" is the model's own name and is not.
  String labelOf(AppLocalizations l10n) => switch (this) {
    SegModel.builtin => l10n.segBuiltinLabel,
    SegModel.u2net => label,
  };

  String taglineOf(AppLocalizations l10n) => switch (this) {
    SegModel.builtin => l10n.segBuiltinTagline,
    SegModel.u2net => l10n.segU2netTagline,
  };

  String blurbOf(AppLocalizations l10n) => switch (this) {
    SegModel.builtin => l10n.segBuiltinBlurb,
    SegModel.u2net => l10n.segU2netBlurb,
  };
}

extension GridTemplateL10n on GridTemplate {
  String labelOf(AppLocalizations l10n) => switch (label) {
    'Side by side' => l10n.gridSideBySide,
    'Stacked' => l10n.gridStacked,
    'Wide left' => l10n.gridWideLeft,
    'Tall top' => l10n.gridTallTop,
    'Columns' => l10n.gridColumns,
    'Rows' => l10n.gridRows,
    'Big left' => l10n.gridBigLeft,
    'Big top' => l10n.gridBigTop,
    '2 x 2' => l10n.gridTwoByTwo,
    '2 over 3' => l10n.gridTwoOverThree,
    '3 over 2' => l10n.gridThreeOverTwo,
    '2 left, 3 right' => l10n.gridTwoLeftThreeRight,
    _ => label,
  };
}

extension CanvasPresetL10n on CanvasPreset {
  String labelOf(AppLocalizations l10n) => switch (label) {
    'Square' => l10n.presetSquare,
    'Portrait' => l10n.presetPortrait,
    'Story' => l10n.presetStory,
    'Landscape' => l10n.presetLandscape,
    'Wide' => l10n.presetWide,
    'Small' => l10n.presetSmall,
    _ => label,
  };
}
