import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// The currently-visible toast, if any. A new toast replaces it so rapid
/// triggers (Undo/Redo/Reset) never stack overlapping pills.
OverlayEntry? _activeToast;

/// Shows a transient toast pinned near the bottom of the screen, matching the
/// design's pill toast with a status dot and pop-in.
///
/// [ok] false paints the dot red instead of green. It used to be green
/// unconditionally, so "Couldn't remove that" arrived wearing a success badge.
///
/// The toast is the app's ONLY channel for several messages that explain why a
/// tap did nothing, so two things matter beyond the look: it is announced to a
/// screen reader (an overlay is not a live region by default, unlike the
/// Material `SnackBar` used elsewhere in the app), and it stays up long enough
/// to read - see [_holdFor].
void showSmToast(BuildContext context, String message, {bool ok = true}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  _activeToast?.remove();
  _activeToast = null;

  unawaited(
    SemanticsService.sendAnnouncement(
      View.of(context),
      message,
      Directionality.of(context),
    ),
  );

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _SmToast(
      message: message,
      ok: ok,
      onDismissed: () {
        if (identical(_activeToast, entry)) _activeToast = null;
        if (entry.mounted) entry.remove();
      },
    ),
  );
  _activeToast = entry;
  overlay.insert(entry);
}

/// How long a toast stays up, scaled by how much there is to read.
///
/// A flat 1.5 s left the pill legible for barely over a second - and the two
/// strings that carry the only explanation of a no-op tap ("That looks like
/// your subject - use Erase for fine edits", and the AI-unavailable message)
/// are the longest in the app. Roughly 45 ms per character, clamped so a short
/// confirmation still feels quick and a long one cannot camp on the canvas.
Duration _holdFor(String message) =>
    Duration(milliseconds: (1500 + message.length * 45).clamp(1500, 6000));

class _SmToast extends StatefulWidget {
  const _SmToast({
    required this.message,
    required this.ok,
    required this.onDismissed,
  });

  final String message;
  final bool ok;
  final VoidCallback onDismissed;

  @override
  State<_SmToast> createState() => _SmToastState();
}

class _SmToastState extends State<_SmToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  late final CurvedAnimation _curved = CurvedAnimation(
    parent: _c,
    curve: Curves.easeOut,
  );
  Timer? _hold;

  @override
  void initState() {
    super.initState();
    _c.forward();
    _hold = Timer(_holdFor(widget.message), () => unawaited(_dismiss()));
  }

  Future<void> _dismiss() async {
    if (!mounted) return;
    await _c.reverse().orCancel.catchError((_) {});
    if (!mounted) return;
    widget.onDismissed();
  }

  @override
  void dispose() {
    _hold?.cancel();
    _curved.dispose();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 40,
      child: IgnorePointer(
        child: Center(
          child: FadeTransition(
            opacity: _curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.4),
                end: Offset.zero,
              ).animate(_curved),
              child: _ToastPill(message: widget.message, ok: widget.ok),
            ),
          ),
        ),
      ),
    );
  }
}

class _ToastPill extends StatelessWidget {
  const _ToastPill({required this.message, required this.ok});

  final String message;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      // The overlay is outside any route's semantics, so without this a screen
      // reader is simply never told the operation finished.
      liveRegion: true,
      label: message,
      child: Material(
        type: MaterialType.transparency,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.chipSurface,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x80000000),
                blurRadius: 30,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: ok ? AppColors.green : AppColors.rose,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  message,
                  style: const TextStyle(
                    fontFamily: AppFonts.ui,
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
