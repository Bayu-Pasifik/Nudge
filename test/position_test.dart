import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/core/util/position.dart';

void main() {
  test('empty list gets the first step', () {
    expect(positionBetween(null, null), positionStep);
  });

  test('insert at start goes below the first item', () {
    expect(positionBetween(null, 1024), lessThan(1024));
  });

  test('insert at end goes above the last item', () {
    expect(positionBetween(2048, null), greaterThan(2048));
  });

  test('insert in the middle lands strictly between neighbours', () {
    final p = positionBetween(1024, 2048);
    expect(p, greaterThan(1024));
    expect(p, lessThan(2048));
  });

  test('repeated inserts eventually need a rebalance', () {
    double a = 1024, b = 2048;
    var n = 0;
    while (!needsRebalance(a, b) && n < 200) {
      b = positionBetween(a, b);
      n++;
    }
    expect(needsRebalance(a, b), isTrue);
    expect(rebalance(3), [1024, 2048, 3072]);
  });
}
