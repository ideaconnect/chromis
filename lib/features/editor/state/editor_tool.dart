import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';

/// The six editor tools, each carrying its own presentation. This is the single
/// source of truth for the tool set; [ToolAccent] stays a pure color key in the
/// theme layer and is mapped from here.
enum EditorTool {
  layers('Layers', 'Layers', Icons.layers_outlined, ToolAccent.layers),
  adjust('Adjust', 'Adjust', Icons.tune, ToolAccent.adjust),
  text('Text', 'Text', Icons.text_fields, ToolAccent.text),
  erase('Erase', 'Manual erase', Icons.brush_outlined, ToolAccent.erase),
  cutout(
    'Cut out',
    'AI Background Removal',
    Icons.auto_awesome_outlined,
    ToolAccent.cutout,
  ),
  frames('Frames', 'Animation frames', Icons.animation, ToolAccent.frames);

  const EditorTool(this.tabLabel, this.panelTitle, this.icon, this.accent);

  /// Short label shown in the bottom tool bar.
  final String tabLabel;

  /// Longer title shown at the top of the tool's contextual panel.
  final String panelTitle;

  final IconData icon;

  /// Color key resolved against [AppTokens].
  final ToolAccent accent;
}
