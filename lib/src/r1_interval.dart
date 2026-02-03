// Copyright 2005 Google Inc. All Rights Reserved.
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

/// An R1Interval represents a closed, bounded interval on the real line.
/// It is capable of representing the empty interval (containing no points)
/// and zero-length intervals (containing a single point).
///
/// This is a mutable class for internal use within the S2 library.
class R1Interval {
  double _lo;
  double _hi;

  /// Creates an interval with the given bounds. If lo > hi, the interval is empty.
  R1Interval(this._lo, this._hi);

  /// Creates an empty interval.
  R1Interval.empty() : _lo = 1, _hi = 0;

  /// Creates a copy of the given interval.
  R1Interval.copy(R1Interval other) : _lo = other._lo, _hi = other._hi;

  /// Convenience method to construct an interval containing a single point.
  static R1Interval fromPoint(double p) => R1Interval(p, p);

  /// Convenience method to construct the minimal interval containing two points.
  static R1Interval fromPointPair(double p1, double p2) {
    if (p1 <= p2) {
      return R1Interval(p1, p2);
    } else {
      return R1Interval(p2, p1);
    }
  }

  /// The low bound of the interval.
  double get lo => _lo;

  /// The high bound of the interval.
  double get hi => _hi;

  /// Sets the low bound.
  set lo(double value) => _lo = value;

  /// Sets the high bound.
  set hi(double value) => _hi = value;

  /// Returns true if the interval is empty.
  bool get isEmpty => _lo > _hi;

  /// Returns the center of the interval. For empty intervals, result is arbitrary.
  double get center => 0.5 * (_lo + _hi);

  /// Returns the length of the interval. Empty intervals have negative length.
  double get length => _hi - _lo;

  /// Returns true if the given point is in the closed interval [lo, hi].
  bool containsPoint(double p) => p >= _lo && p <= _hi;

  /// Returns true if the given point is in the open interval (lo, hi).
  bool interiorContainsPoint(double p) => p > _lo && p < _hi;

  /// Returns true if this interval contains the interval y.
  bool contains(R1Interval y) {
    if (y.isEmpty) return true;
    return y._lo >= _lo && y._hi <= _hi;
  }

  /// Returns true if the interior of this interval contains the entire interval y.
  bool interiorContains(R1Interval y) {
    if (y.isEmpty) return true;
    return y._lo > _lo && y._hi < _hi;
  }

  /// Returns true if this interval intersects y.
  bool intersects(R1Interval y) {
    if (_lo <= y._lo) {
      return y._lo <= _hi && y._lo <= y._hi;
    } else {
      return _lo <= y._hi && _lo <= _hi;
    }
  }

  /// Returns true if the interior of this interval intersects any point of y.
  bool interiorIntersects(R1Interval y) {
    return y._lo < _hi && _lo < y._hi && _lo < _hi && y._lo <= y._hi;
  }

  /// Returns the Hausdorff distance to the given interval y.
  double getDirectedHausdorffDistance(R1Interval y) {
    if (isEmpty) return 0.0;
    if (y.isEmpty) return double.maxFinite;
    return math.max(0.0, math.max(_hi - y._hi, y._lo - _lo));
  }

  /// Sets both bounds of the interval.
  void set(double lo, double hi) {
    _lo = lo;
    _hi = hi;
  }

  /// Sets the interval to empty.
  void setEmpty() {
    _lo = 1;
    _hi = 0;
  }

  /// Returns the closest point in the interval to p. The interval must be non-empty.
  double clampPoint(double p) {
    assert(!isEmpty);
    return math.max(_lo, math.min(_hi, p));
  }

  /// Returns an interval expanded on each side by margin.
  R1Interval expanded(double margin) {
    if (isEmpty) return this;
    return R1Interval(_lo - margin, _hi + margin);
  }

  /// Returns the smallest interval that contains this interval and y.
  R1Interval union(R1Interval y) {
    if (isEmpty) return y;
    if (y.isEmpty) return this;
    return R1Interval(math.min(_lo, y._lo), math.max(_hi, y._hi));
  }

  /// Returns the intersection of this interval with y.
  R1Interval intersection(R1Interval y) {
    return R1Interval(math.max(_lo, y._lo), math.min(_hi, y._hi));
  }

  /// Returns the smallest interval that contains this interval and point p.
  R1Interval addPoint(double p) {
    if (isEmpty) return R1Interval.fromPoint(p);
    if (p < _lo) return R1Interval(p, _hi);
    if (p > _hi) return R1Interval(_lo, p);
    return R1Interval(_lo, _hi);
  }

  /// Expands this interval to contain point p (mutating).
  void unionInternal(double p) {
    if (isEmpty) {
      _lo = p;
      _hi = p;
    } else if (p < _lo) {
      _lo = p;
    } else if (p > _hi) {
      _hi = p;
    }
  }

  /// Sets this interval to the union with y (mutating).
  void unionInternalInterval(R1Interval y) {
    if (isEmpty) {
      _lo = y._lo;
      _hi = y._hi;
    } else if (!y.isEmpty) {
      _lo = math.min(_lo, y._lo);
      _hi = math.max(_hi, y._hi);
    }
  }

  /// Sets this interval to intersection with y (mutating).
  void intersectionInternal(R1Interval y) {
    _lo = math.max(_lo, y._lo);
    _hi = math.min(_hi, y._hi);
  }

  /// Expands this interval by radius on each side (mutating).
  void expandedInternal(double radius) {
    _lo -= radius;
    _hi += radius;
  }

  @override
  bool operator ==(Object other) {
    if (other is R1Interval) {
      return (_lo == other._lo && _hi == other._hi) || (isEmpty && other.isEmpty);
    }
    return false;
  }

  @override
  int get hashCode {
    if (isEmpty) return 17;
    var value = 17;
    value = 37 * value + _lo.hashCode;
    value = 37 * value + _hi.hashCode;
    return value;
  }

  /// Returns true if this interval equals y within maxError.
  bool approxEquals(R1Interval y, [double maxError = 1e-15]) {
    if (isEmpty) return y.length <= maxError;
    if (y.isEmpty) return length <= maxError;
    return (y._lo - _lo).abs() <= maxError && (y._hi - _hi).abs() <= maxError;
  }

  @override
  String toString() => '[$_lo, $_hi]';
}

