import 'package:flutter/widgets.dart';

/// Whether this is a tablet-class screen, i.e. one big enough to deserve a
/// layout of its own rather than a phone layout with wider margins.
///
/// Measured on the SHORTEST side on purpose: that is orientation-independent,
/// so a 412x915 phone reads as 412 whichever way it is held. Testing `width`
/// instead would call a phone in landscape a tablet, which is precisely the
/// phone regression this exists to avoid.
bool isTabletWidth(BuildContext context) =>
    MediaQuery.sizeOf(context).shortestSide >= 600;

/// Constrains [child] to [maxWidth] and centres it on wide screens (tablets,
/// foldables, desktop) so a phone-first layout doesn't stretch into unreadable
/// full-width rows. On a screen narrower than [maxWidth] it's a no-op - the
/// child fills the available width exactly as before. (#65)
class ResponsiveCenter extends StatelessWidget {
  const ResponsiveCenter({super.key, required this.child, this.maxWidth = 560});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
