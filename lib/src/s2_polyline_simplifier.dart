// Copyright 2022 Google Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'dart:math' as math;

import 'platform.dart';
import 's1_chord_angle.dart';
import 's1_interval.dart';
import 's2.dart';
import 's2_point.dart';
import 's2_predicates.dart';

/// A helper class for simplifying polylines. It allows you to compute a
/// maximal edge that intersects a sequence of discs, and that optionally
/// avoids a different sequence of discs.
///
/// Note that S2Builder can also simplify polylines and supports more features
/// (e.g., snapping to S2CellId centers), so it is only recommended to use this
/// class if S2Builder does not meet your needs.
///
/// Example usage:
/// ```dart
/// List<S2Point> v = [...];
/// S2PolylineSimplifier simplifier = S2PolylineSimplifier();
/// simplifier.init(v[0]);
/// for (int i = 1; i < v.length; ++i) {
///   if (!simplifier.extend(v[i])) {
///     outputEdge(simplifier.src, v[i - 1]);
///     simplifier.init(v[i - 1]);
///   }
///   simplifier.targetDisc(v[i], maxError);
/// }
/// outputEdge(simplifier.src, v.last);
/// ```
class S2PolylineSimplifier {
  /// Output edge source vertex.
  S2Point _src = const S2Point(0, 0, 0);

  /// First vector of an orthonormal frame for mapping vectors to angles.
  S2Point _xDir = const S2Point(0, 0, 0);

  /// Second vector of an orthonormal frame for mapping vectors to angles.
  S2Point _yDir = const S2Point(0, 0, 0);

  /// Allowable range of angles for the output edge.
  S1Interval _window = S1Interval.full();

  /// Discs to avoid stored until targetDisc() is first called.
  final List<_RangeToAvoid> _rangesToAvoid = [];

  /// Returns the source vertex of the current edge.
  S2Point get src => _src;

  /// Starts a new simplified edge at [src].
  void init(S2Point src) {
    _src = src;
    _window = S1Interval.full();
    _rangesToAvoid.clear();

    // Precompute basis vectors for the tangent space at "src".
    final tmp = S2Point(src.x.abs(), src.y.abs(), src.z.abs());
    final i = tmp.x < tmp.y ? (tmp.x < tmp.z ? 0 : 2) : (tmp.y < tmp.z ? 1 : 2);

    final s = [src.x, src.y, src.z];
    final xVector = [0.0, 0.0, 0.0];
    final yVector = [0.0, 0.0, 0.0];

    final j = (i == 2 ? 0 : i + 1);
    final k = (i == 0 ? 2 : i - 1);
    yVector[i] = 0;
    yVector[j] = s[k];
    yVector[k] = -s[j];

    xVector[i] = s[j] * s[j] + s[k] * s[k];
    xVector[j] = -s[j] * s[i];
    xVector[k] = -s[k] * s[i];

    _xDir = S2Point(xVector[0], xVector[1], xVector[2]);
    _yDir = S2Point(yVector[0], yVector[1], yVector[2]);
  }

  /// Returns true if the edge (src, dst) satisfies all of the targeting
  /// requirements so far. Returns false if the edge would be longer than
  /// 90 degrees or cannot satisfy the constraints.
  bool extend(S2Point dst) {
    final edgeLength = S1ChordAngle.fromPoints(_src, dst);
    if (edgeLength.greaterThan(S1ChordAngle.RIGHT)) {
      return false;
    }

    final dir = _getDirection(dst);
    if (!_window.containsPoint(dir)) {
      return false;
    }

    for (final range in _rangesToAvoid) {
      if (range.interval.containsPoint(dir)) {
        return false;
      }
    }
    return true;
  }

  /// Requires that the output edge must pass through the disc specified by
  /// the given point and radius.
  ///
  /// Returns true if it is possible to intersect the target disc, given
  /// previous constraints.
  bool targetDisc(S2Point point, S1ChordAngle radius) {
    final semiwidth = _getSemiwidth(point, radius, -1);
    if (semiwidth >= math.pi) {
      return true;
    }
    if (semiwidth < 0) {
      _window = S1Interval.empty();
      return false;
    }

    final center = _getDirection(point);
    final target = S1Interval.fromPoint(center).expanded(semiwidth);
    _window = _window.intersection(target);

    for (final range in _rangesToAvoid) {
      _avoidRange(range.interval, range.onLeft);
    }
    _rangesToAvoid.clear();

    return !_window.isEmpty;
  }

  /// Requires that the output edge must avoid the given disc. [discOnLeft]
  /// specifies whether the disc must be to the left or right of the output
  /// edge AB.
  ///
  /// Returns true if the disc can be avoided given previous constraints.
  bool avoidDisc(S2Point point, S1ChordAngle radius, bool discOnLeft) {
    final semiwidth = _getSemiwidth(point, radius, 1);
    if (semiwidth >= math.pi) {
      _window = S1Interval.empty();
      return false;
    }

    final center = _getDirection(point);
    final dLeft = discOnLeft ? S2.mPi2 : semiwidth;
    final dRight = discOnLeft ? semiwidth : S2.mPi2;
    final avoidInterval = S1Interval(
      Platform.ieeeRemainder(center - dRight, 2 * math.pi),
      Platform.ieeeRemainder(center + dLeft, 2 * math.pi),
    );

    if (_window.isFull) {
      _rangesToAvoid.add(_RangeToAvoid(avoidInterval, discOnLeft));
      return true;
    }
    _avoidRange(avoidInterval, discOnLeft);
    return !_window.isEmpty;
  }

  double _getDirection(S2Point p) {
    return math.atan2(p.dotProd(_yDir), p.dotProd(_xDir));
  }

  /// Computes half the angle in radians subtended from the source vertex by a
  /// disc of radius [r] centered at [p], rounding the result conservatively.
  double _getSemiwidth(S2Point p, S1ChordAngle r, int roundDirection) {
    final r2 = r.length2;
    var a2 = S1ChordAngle.fromPoints(_src, p).length2;
    a2 -= 64 * S2Predicates.dblErr * S2Predicates.dblErr * roundDirection;
    if (a2 <= r2) {
      return math.pi; // The given disc contains "src".
    }

    final sin2R = r2 * (1 - 0.25 * r2);
    final sin2A = a2 * (1 - 0.25 * a2);
    final semiwidth = math.asin(math.sqrt(sin2R / sin2A));

    final error = (2 * 10 + 4) * S2Predicates.dblErr +
        17 * S2Predicates.dblErr * semiwidth;
    return semiwidth + roundDirection * error;
  }

  void _avoidRange(S1Interval avoidInterval, bool discOnLeft) {
    assert(!_window.isFull);
    if (_window.contains(avoidInterval)) {
      if (discOnLeft) {
        _window = S1Interval(_window.lo, avoidInterval.lo);
      } else {
        _window = S1Interval(avoidInterval.hi, _window.hi);
      }
    } else {
      _window = _window.intersection(avoidInterval.complement());
    }
  }
}

/// Range of directions to avoid.
class _RangeToAvoid {
  final S1Interval interval;
  final bool onLeft;

  _RangeToAvoid(this.interval, this.onLeft);
}
