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

import 'platform.dart';

/// An S1Interval represents a closed interval on a unit circle (1D sphere).
/// It can represent empty, full, and zero-length intervals.
/// Points are represented by the angle they make with the positive x-axis
/// in the range [-Pi, Pi].
class S1Interval {
  double _lo;
  double _hi;

  /// Creates an empty interval (default constructor).
  S1Interval.init()
      : _lo = math.pi,
        _hi = -math.pi;

  /// Creates an empty interval.
  S1Interval.empty()
      : _lo = math.pi,
        _hi = -math.pi;

  /// Creates a full interval covering all points.
  S1Interval.full()
      : _lo = -math.pi,
        _hi = math.pi;

  /// Both endpoints must be in range -Pi to Pi.
  S1Interval(double lo, double hi)
      : _lo = lo,
        _hi = hi {
    _normalize(false);
  }

  /// Copy constructor.
  S1Interval.copy(S1Interval other)
      : _lo = other._lo,
        _hi = other._hi;

  void _normalize(bool checked) {
    if (!checked) {
      // Normalize -pi to pi for both endpoints.
      // Store original values to check conditions correctly.
      final origLo = _lo;
      final origHi = _hi;
      if (origLo == -math.pi && origHi != math.pi) _lo = math.pi;
      if (origHi == -math.pi && origLo != math.pi) _hi = math.pi;
    }
  }

  /// Creates an interval containing a single point.
  static S1Interval fromPoint(double radians) {
    var p = radians;
    if (p == -math.pi) p = math.pi;
    return S1Interval._checked(p, p);
  }

  /// Creates the minimal interval containing two points.
  static S1Interval fromPointPair(double p1, double p2) {
    assert(p1.abs() <= math.pi);
    assert(p2.abs() <= math.pi);
    final result = S1Interval.empty();
    result._initFromPointPair(p1, p2);
    return result;
  }

  S1Interval._checked(this._lo, this._hi);

  void _initFromPointPair(double p1, double p2) {
    if (p1 == -math.pi) p1 = math.pi;
    if (p2 == -math.pi) p2 = math.pi;
    if (_positiveDistance(p1, p2) <= math.pi) {
      _lo = p1;
      _hi = p2;
    } else {
      _lo = p2;
      _hi = p1;
    }
  }

  double get lo => _lo;
  double get hi => _hi;

  /// Sets both endpoints.
  void set(double lo, double hi, bool checked) {
    _lo = lo;
    _hi = hi;
    if (!checked) _normalize(false);
  }

  /// Sets interval to empty.
  void setEmpty() {
    _lo = math.pi;
    _hi = -math.pi;
  }

  /// Sets interval to full.
  void setFull() {
    _lo = -math.pi;
    _hi = math.pi;
  }

  bool get isValid =>
      (_lo.abs() <= math.pi && _hi.abs() <= math.pi) &&
      !(_lo == -math.pi && _hi != math.pi) &&
      !(_hi == -math.pi && _lo != math.pi);

  bool get isFull => _lo == -math.pi && _hi == math.pi;
  bool get isEmpty => _lo == math.pi && _hi == -math.pi;
  bool get isInverted => _lo > _hi;

  /// Returns the midpoint of the interval.
  double get center {
    final c = 0.5 * (_lo + _hi);
    if (!isInverted) return c;
    return (c <= 0) ? (c + math.pi) : (c - math.pi);
  }

  /// Returns the length of the interval.
  double get length {
    var len = _hi - _lo;
    if (len >= 0) return len;
    len += 2 * math.pi;
    return (len > 0) ? len : -1;
  }

  /// Returns the center of the interval. Method form for Java compatibility.
  double getCenter() => center;

  /// Returns the length of the interval. Method form for Java compatibility.
  double getLength() => length;

  /// Gets endpoint by index (0 = lo, 1 = hi).
  double get(int i) => i == 0 ? _lo : _hi;

  /// Returns the directed Hausdorff distance to the given interval.
  /// For two S1Intervals x and y, this distance is defined by
  /// h(x, y) = max{p in x} min{q in y} d(p, q), where d(.,.) is measured along S1.
  double getDirectedHausdorffDistance(S1Interval y) {
    if (y.contains(this)) {
      return 0.0; // this includes the case this is empty
    }
    if (y.isEmpty) {
      return math.pi; // maximum possible distance on S1
    }

    final yComplementCenter = y.complementCenter;
    if (containsPoint(yComplementCenter)) {
      return _positiveDistance(y._hi, yComplementCenter);
    } else {
      // The Hausdorff distance is realized by either two hi() endpoints or two
      // lo() endpoints, whichever is farther apart.
      final hiHi = S1Interval._checked(y._hi, yComplementCenter).containsPoint(_hi)
          ? _positiveDistance(y._hi, _hi)
          : 0.0;
      final loLo = S1Interval._checked(yComplementCenter, y._lo).containsPoint(_lo)
          ? _positiveDistance(_lo, y._lo)
          : 0.0;
      assert(hiHi > 0 || loLo > 0);
      return hiHi > loLo ? hiHi : loLo;
    }
  }

  /// Returns the complement of the interior.
  S1Interval complement() {
    if (_lo == _hi) return S1Interval.full();
    return S1Interval._checked(_hi, _lo);
  }

  double get complementCenter {
    if (_lo != _hi) return complement().center;
    return (_hi <= 0) ? (_hi + math.pi) : (_hi - math.pi);
  }

  /// Returns true if the interval contains point p.
  bool containsPoint(double p) {
    assert(p.abs() <= math.pi);
    if (p == -math.pi) p = math.pi;
    return fastContains(p);
  }

  /// Fast contains check (no normalization of p).
  bool fastContains(double p) {
    if (isInverted) {
      return (p >= _lo || p <= _hi) && !isEmpty;
    }
    return p >= _lo && p <= _hi;
  }

  /// Returns true if the interval contains interval y.
  bool contains(S1Interval y) {
    if (isInverted) {
      if (y.isInverted) return y._lo >= _lo && y._hi <= _hi;
      return (y._lo >= _lo || y._hi <= _hi) && !isEmpty;
    } else {
      if (y.isInverted) return isFull || y.isEmpty;
      return y._lo >= _lo && y._hi <= _hi;
    }
  }

  /// Returns true if the interior contains point p.
  bool interiorContainsPoint(double p) {
    assert(p.abs() <= math.pi);
    if (p == -math.pi) p = math.pi;
    if (isInverted) return p > _lo || p < _hi;
    return (p > _lo && p < _hi) || isFull;
  }

  /// Returns true if the interior contains interval y.
  bool interiorContains(S1Interval y) {
    if (isInverted) {
      if (!y.isInverted) return y._lo > _lo || y._hi < _hi;
      return (y._lo > _lo && y._hi < _hi) || y.isEmpty;
    } else {
      if (y.isInverted) return isFull || y.isEmpty;
      return (y._lo > _lo && y._hi < _hi) || isFull;
    }
  }

  /// Returns true if the intervals share any points.
  bool intersects(S1Interval y) {
    if (isEmpty || y.isEmpty) return false;
    if (isInverted) return y.isInverted || y._lo <= _hi || y._hi >= _lo;
    if (y.isInverted) return y._lo <= _hi || y._hi >= _lo;
    return y._lo <= _hi && y._hi >= _lo;
  }

  /// Returns true if the interior intersects any point of y.
  bool interiorIntersects(S1Interval y) {
    if (isEmpty || y.isEmpty || _lo == _hi) return false;
    if (isInverted) return y.isInverted || y._lo < _hi || y._hi > _lo;
    if (y.isInverted) return y._lo < _hi || y._hi > _lo;
    return (y._lo < _hi && y._hi > _lo) || isFull;
  }

  /// Returns a new interval expanded to include point p.
  S1Interval addPoint(double p) {
    assert(p.abs() <= math.pi);
    if (p == -math.pi) p = math.pi;
    if (fastContains(p)) return S1Interval.copy(this);
    if (isEmpty) return S1Interval.fromPoint(p);
    final dlo = _positiveDistance(p, _lo);
    final dhi = _positiveDistance(_hi, p);
    return dlo < dhi ? S1Interval(p, _hi) : S1Interval(_lo, p);
  }

  /// Returns the closest point in the interval to p.
  double clampPoint(double p) {
    assert(!isEmpty);
    assert(p.abs() <= math.pi);
    if (p == -math.pi) p = math.pi;
    if (fastContains(p)) return p;
    final dlo = _positiveDistance(p, _lo);
    final dhi = _positiveDistance(_hi, p);
    return (dlo < dhi) ? _lo : _hi;
  }

  /// Returns an expanded interval.
  S1Interval expanded(double margin) {
    final copy = S1Interval.copy(this);
    copy._expandedInternal(margin);
    return copy;
  }

  void _expandedInternal(double margin) {
    if (margin >= 0) {
      if (isEmpty) return;
      // Check whether this interval will be full after expansion, allowing for
      // a 1-bit rounding error when computing each endpoint.
      if (length + 2 * margin + 2 * Platform.dblEpsilon >= 2 * math.pi) {
        setFull();
        return;
      }
    } else {
      if (isFull) return;
      // Check whether this interval will be empty after expansion, allowing for
      // a 1-bit rounding error when computing each endpoint.
      if (length + 2 * margin - 2 * Platform.dblEpsilon <= 0) {
        setEmpty();
        return;
      }
    }
    set(Platform.ieeeRemainder(_lo - margin, 2 * math.pi),
        Platform.ieeeRemainder(_hi + margin, 2 * math.pi), false);
    if (_lo <= -math.pi) _lo = math.pi;
  }

  /// Returns the smallest interval containing this and y.
  S1Interval union(S1Interval y) {
    final result = S1Interval.copy(this);
    result.unionInternal(y);
    return result;
  }

  /// Mutates this interval to include y.
  void unionInternal(S1Interval y) {
    if (y.isEmpty) return;
    if (fastContains(y._lo)) {
      if (fastContains(y._hi)) {
        if (!contains(y)) setFull();
      } else {
        _hi = y._hi;
      }
    } else if (fastContains(y._hi)) {
      _lo = y._lo;
    } else if (isEmpty || y.fastContains(_lo)) {
      _lo = y._lo;
      _hi = y._hi;
    } else {
      final dlo = _positiveDistance(y._hi, _lo);
      final dhi = _positiveDistance(_hi, y._lo);
      if (dlo < dhi) {
        _lo = y._lo;
      } else {
        _hi = y._hi;
      }
    }
  }

  /// Returns the intersection with y.
  S1Interval intersection(S1Interval y) {
    final result = S1Interval.copy(this);
    result.intersectionInternal(y);
    return result;
  }

  void intersectionInternal(S1Interval y) {
    if (y.isEmpty) {
      setEmpty();
    } else if (fastContains(y._lo)) {
      if (fastContains(y._hi)) {
        if (y.length < length) set(y._lo, y._hi, true);
      } else {
        set(y._lo, _hi, true);
      }
    } else if (fastContains(y._hi)) {
      set(_lo, y._hi, true);
    } else {
      if (!y.fastContains(_lo)) setEmpty();
    }
  }

  static double _positiveDistance(double a, double b) {
    final d = b - a;
    if (d >= 0) return d;
    return (b + math.pi) - (a - math.pi);
  }

  bool approxEquals(S1Interval y, [double maxError = 1e-15]) {
    if (isEmpty) return y.length <= 2 * maxError;
    if (y.isEmpty) return length <= 2 * maxError;
    if (isFull) return y.length >= 2 * (math.pi - maxError);
    if (y.isFull) return length >= 2 * (math.pi - maxError);
    return (Platform.ieeeRemainder(y._lo - _lo, 2 * math.pi)).abs() <= maxError &&
        (Platform.ieeeRemainder(y._hi - _hi, 2 * math.pi)).abs() <= maxError &&
        (length - y.length).abs() <= 2 * maxError;
  }

  @override
  bool operator ==(Object other) {
    if (other is S1Interval) return _lo == other._lo && _hi == other._hi;
    return false;
  }

  @override
  int get hashCode {
    var value = 17;
    value = 37 * value + _lo.hashCode;
    value = 37 * value + _hi.hashCode;
    return value;
  }

  @override
  String toString() => '[$_lo, $_hi]';
}
