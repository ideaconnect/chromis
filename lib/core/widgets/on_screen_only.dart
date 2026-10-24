import 'package:flutter/widgets.dart';

/// Builds [child] only while the route it sits in can be seen, and nothing
/// once another route has covered it.
///
/// For platform views, which do not stop when they are covered. A route under
/// an opaque one stays mounted - Flutter keeps its state - and so does every
/// Android view it hosts: the Home banner's `AdView` stayed attached and
/// VISIBLE under the editor and the export screen, so its WebView went on
/// rendering frames nobody could see (#67). Each of those frames costs our
/// main thread a round trip to the ad's renderer process, waited on with no
/// timeout, and the editor is where the AI tools keep every core busy.
/// Taking the platform view out of the tree detaches the view; the widget
/// that owns it (here a loaded `BannerAd`) survives, so coming back
/// re-attaches the same view rather than starting over.
///
/// The signal is [TickerMode], which [Overlay] turns off for every entry under
/// an opaque one. A route that is animating in or out is never opaque, so the
/// child is there for the whole of a push, pop or predictive-back transition,
/// and goes only once the route above has finished arriving.
class OnScreenOnly extends StatelessWidget {
  const OnScreenOnly({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      TickerMode.valuesOf(context).enabled ? child : const SizedBox.shrink();
}
