/// Fractional indexing for drag-and-drop ordering. Inserting between two
/// neighbours only changes one row.
const double positionStep = 1024;

/// Returns a position strictly between [before] and [after].
/// Pass null for an open end (start/end of the list).
double positionBetween(double? before, double? after) {
  if (before == null && after == null) return positionStep;
  if (before == null) return after! - positionStep;
  if (after == null) return before + positionStep;
  return (before + after) / 2;
}

/// True when two neighbours are too close for another midpoint insert and the
/// list should be re-spaced.
bool needsRebalance(double a, double b) => (b - a).abs() < 1e-6;

/// Evenly re-spaced positions for [count] items.
List<double> rebalance(int count) =>
    List.generate(count, (i) => (i + 1) * positionStep);
