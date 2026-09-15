import 'dart:math' as math;

/// How many columns a tile grid should use for a window [width] logical pixels
/// wide.
///
/// Always call this with the width from the *current* constraints (a
/// `LayoutBuilder`), never with a value captured once at startup. On a folding
/// phone the window changes size while the app is running, so a breakpoint
/// sampled at launch keeps the folded layout after the device is unfolded —
/// which is the single most common foldable bug.
///
/// [tileExtent] is the width a tile wants; [min] keeps the familiar phone
/// layout on the narrowest cover displays and [max] stops the grid from
/// turning into a thin strip of tiles on a near-square unfolded window.
int adaptiveTileColumns(
  double width, {
  double tileExtent = 120,
  int min = 3,
  int max = 6,
}) {
  if (!width.isFinite || width <= 0) return min;
  final columns = (width / tileExtent).floor();
  return math.min(math.max(columns, min), max);
}
