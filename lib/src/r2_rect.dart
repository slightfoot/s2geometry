// Copyright 2013 Google Inc. All Rights Reserved.
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

import 'r1_interval.dart';
import 'r2_vector.dart';

/// Axis enum for R2Rect (Java compatibility).
enum Axis { X, Y }

/// An R2Rect represents a closed axis-aligned rectangle in the (x,y) plane.
/// This class is mutable to allow iteratively constructing bounds.
class R2Rect {
  final R1Interval _x;
  final R1Interval _y;

  /// Creates an empty R2Rect (default constructor, Java compatibility).
  R2Rect.empty()
      : _x = R1Interval.empty(),
        _y = R1Interval.empty();

  /// Constructs a rectangle from the given lower-left and upper-right points.
  /// This also matches Java's: new R2Rect(R2Vector lo, R2Vector hi)
  R2Rect.fromPoints(R2Vector lo, R2Vector hi)
      : _x = R1Interval(lo.x, hi.x),
        _y = R1Interval(lo.y, hi.y);

  /// Constructs a rectangle from the given intervals.
  R2Rect(R1Interval x, R1Interval y)
      : _x = x,
        _y = y;

  /// Copy constructor (matches Java's: new R2Rect(R2Rect rect)).
  R2Rect.copy(R2Rect rect)
      : _x = R1Interval.copy(rect._x),
        _y = R1Interval.copy(rect._y);

  /// Factory to create R2Rect from two R2Vector points (Java compatibility).
  factory R2Rect.fromVectors(R2Vector lo, R2Vector hi) = R2Rect.fromPoints;

  /// Returns a rectangle from center point and size.
  static R2Rect fromCenterSize(R2Vector center, R2Vector size) {
    return R2Rect(
      R1Interval(center.x - 0.5 * size.x, center.x + 0.5 * size.x),
      R1Interval(center.y - 0.5 * size.y, center.y + 0.5 * size.y),
    );
  }

  /// Returns a rectangle containing a single point.
  static R2Rect fromPoint(R2Vector p) => R2Rect.fromPoints(p, p);

  /// Returns the minimal bounding rectangle containing two points.
  static R2Rect fromPointPair(R2Vector p1, R2Vector p2) {
    return R2Rect(
      R1Interval.fromPointPair(p1.x, p2.x),
      R1Interval.fromPointPair(p1.y, p2.y),
    );
  }

  /// The interval along the x-axis.
  R1Interval get x => _x;

  /// The interval along the y-axis.
  R1Interval get y => _y;

  /// Returns the interval for the specified axis (Java compatibility).
  R1Interval getInterval(Axis axis) {
    return axis == Axis.X ? _x : _y;
  }

  /// The point with minimum x and y values.
  R2Vector get lo => R2Vector(_x.lo, _y.lo);

  /// The point with maximum x and y values.
  R2Vector get hi => R2Vector(_x.hi, _y.hi);

  /// Returns true if the rectangle is valid.
  bool get isValid => _x.isEmpty == _y.isEmpty;

  /// Returns true if the rectangle is empty.
  bool get isEmpty => _x.isEmpty;

  /// Returns the k-th vertex (k=0,1,2,3) in CCW order.
  R2Vector getVertex(int k) {
    k = k & 3;
    return getVertexIJ((k >> 1) ^ (k & 1), k >> 1);
  }

  /// Returns the vertex at direction i along x-axis and j along y-axis.
  R2Vector getVertexIJ(int i, int j) {
    return R2Vector(i == 0 ? _x.lo : _x.hi, j == 0 ? _y.lo : _y.hi);
  }

  /// Returns the center of the rectangle.
  R2Vector get center => R2Vector(_x.center, _y.center);

  /// Returns the center of the rectangle (Java compatibility).
  R2Vector getCenter() => center;

  /// Returns the size of the rectangle.
  R2Vector get size => R2Vector(_x.length, _y.length);

  /// Returns the size of the rectangle (Java compatibility).
  R2Vector getSize() => size;

  /// Returns true if this rectangle contains point p (overloaded for R2Vector).
  bool contains(dynamic p) {
    if (p is R2Vector) {
      return _x.containsPoint(p.x) && _y.containsPoint(p.y);
    } else if (p is R2Rect) {
      return _x.contains(p._x) && _y.contains(p._y);
    }
    throw ArgumentError('Argument must be R2Vector or R2Rect');
  }

  /// Returns true if this rectangle contains point p.
  bool containsPoint(R2Vector p) => _x.containsPoint(p.x) && _y.containsPoint(p.y);

  /// Returns true if the interior contains point (overloaded).
  bool interiorContains(dynamic p) {
    if (p is R2Vector) {
      return _x.interiorContainsPoint(p.x) && _y.interiorContainsPoint(p.y);
    } else if (p is R2Rect) {
      return _x.interiorContains(p._x) && _y.interiorContains(p._y);
    }
    throw ArgumentError('Argument must be R2Vector or R2Rect');
  }

  /// Returns true if the interior contains point p.
  bool interiorContainsPoint(R2Vector p) =>
      _x.interiorContainsPoint(p.x) && _y.interiorContainsPoint(p.y);

  /// Returns true if this rectangle contains other.
  bool containsRect(R2Rect other) => _x.contains(other._x) && _y.contains(other._y);

  /// Returns true if the interior contains other.
  bool interiorContainsRect(R2Rect other) =>
      _x.interiorContains(other._x) && _y.interiorContains(other._y);

  /// Returns true if this rectangle intersects other.
  bool intersects(R2Rect other) => _x.intersects(other._x) && _y.intersects(other._y);

  /// Returns true if the interior intersects other.
  bool interiorIntersects(R2Rect other) =>
      _x.interiorIntersects(other._x) && _y.interiorIntersects(other._y);

  /// Expands the rectangle to include point p.
  void addPoint(R2Vector p) {
    _x.unionInternal(p.x);
    _y.unionInternal(p.y);
  }

  /// Expands the rectangle to include other.
  void addRect(R2Rect other) {
    _x.unionInternalInterval(other._x);
    _y.unionInternalInterval(other._y);
  }

  /// Returns the closest point in this rectangle to p.
  R2Vector clampPoint(R2Vector p) => R2Vector(_x.clampPoint(p.x), _y.clampPoint(p.y));

  /// Returns a rectangle expanded by margin on each side.
  R2Rect expanded(dynamic margin) {
    if (margin is R2Vector) {
      final xx = _x.expanded(margin.x);
      final yy = _y.expanded(margin.y);
      if (xx.isEmpty || yy.isEmpty) return R2Rect.empty();
      return R2Rect(xx, yy);
    } else if (margin is double) {
      final xx = _x.expanded(margin);
      final yy = _y.expanded(margin);
      if (xx.isEmpty || yy.isEmpty) return R2Rect.empty();
      return R2Rect(xx, yy);
    }
    throw ArgumentError('Argument must be R2Vector or double');
  }

  /// Returns the union of this rectangle with other.
  R2Rect union(R2Rect other) => R2Rect(_x.union(other._x), _y.union(other._y));

  /// Returns the intersection of this rectangle with other.
  R2Rect intersection(R2Rect other) {
    final xx = _x.intersection(other._x);
    final yy = _y.intersection(other._y);
    if (xx.isEmpty || yy.isEmpty) return R2Rect.empty();
    return R2Rect(xx, yy);
  }

  @override
  bool operator ==(Object other) {
    if (other is R2Rect) {
      return _x == other._x && _y == other._y;
    }
    return false;
  }

  @override
  int get hashCode => _x.hashCode * 701 + _y.hashCode;

  bool approxEquals(R2Rect other, [double maxError = 1e-15]) {
    return _x.approxEquals(other._x, maxError) && _y.approxEquals(other._y, maxError);
  }

  @override
  String toString() => '[Lo$lo, Hi$hi]';
}
