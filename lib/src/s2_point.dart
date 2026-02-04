// Copyright 2006 Google Inc. All Rights Reserved.
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

/// An S2Point represents a point on the unit sphere as a 3D vector.
/// Usually points are normalized to be unit length, but some methods do not
/// require this. S2Points are immutable.
class S2Point implements Comparable<S2Point> {
  /// Origin of the coordinate system, [0,0,0].
  static const S2Point zero = S2Point(0, 0, 0);

  /// Origin (uppercase, Java compatibility).
  static const S2Point ZERO = zero;

  /// Direction of the x-axis.
  static const S2Point xPos = S2Point(1, 0, 0);

  /// X_POS (uppercase, Java compatibility).
  static const S2Point X_POS = xPos;

  /// Opposite direction of the x-axis.
  static const S2Point xNeg = S2Point(-1, 0, 0);

  /// X_NEG (uppercase, Java compatibility).
  static const S2Point X_NEG = xNeg;

  /// Direction of the y-axis.
  static const S2Point yPos = S2Point(0, 1, 0);

  /// Y_POS (uppercase, Java compatibility).
  static const S2Point Y_POS = yPos;

  /// Opposite direction of the y-axis.
  static const S2Point yNeg = S2Point(0, -1, 0);

  /// Y_NEG (uppercase, Java compatibility).
  static const S2Point Y_NEG = yNeg;

  /// Direction of the z-axis.
  static const S2Point zPos = S2Point(0, 0, 1);

  /// Z_POS (uppercase, Java compatibility).
  static const S2Point Z_POS = zPos;

  /// Opposite direction of the z-axis.
  static const S2Point zNeg = S2Point(0, 0, -1);

  /// Z_NEG (uppercase, Java compatibility).
  static const S2Point Z_NEG = zNeg;

  final double x;
  final double y;
  final double z;

  /// Constructs an S2Point from the given coordinates.
  const S2Point(this.x, this.y, this.z);

  /// Constructs an S2Point from a vector of doubles in order x, y, z.
  S2Point.fromList(List<double> vec) : this(vec[0], vec[1], vec[2]);

  /// Returns true if this S2Point is valid (none of its components are infinite or NaN).
  bool get isValid => x.isFinite && y.isFinite && z.isFinite;

  /// Returns the value of one of the components by axis index (0=x, 1=y, 2=z).
  double operator [](int axis) {
    switch (axis) {
      case 0:
        return x;
      case 1:
        return y;
      case 2:
        return z;
      default:
        throw RangeError.index(axis, this, 'axis', null, 3);
    }
  }

  /// Returns the component-wise addition of this and p.
  S2Point operator +(S2Point p) => S2Point(x + p.x, y + p.y, z + p.z);

  /// Returns the component-wise subtraction of this and p.
  S2Point operator -(S2Point p) => S2Point(x - p.x, y - p.y, z - p.z);

  /// Returns this point scaled by m.
  S2Point operator *(double m) => S2Point(m * x, m * y, m * z);

  /// Returns this point divided by m.
  S2Point operator /(double m) => S2Point(x / m, y / m, z / m);

  /// Returns the negation of this point.
  S2Point operator -() => S2Point(-x, -y, -z);

  /// Returns the negation of this point (method form).
  S2Point neg() => -this;

  /// Returns this minus the other point (method form).
  S2Point sub(S2Point that) => this - that;

  /// Returns this plus the other point (method form).
  S2Point add(S2Point that) => this + that;

  /// Returns this point scaled by m (method form, Java compatibility).
  S2Point mul(double m) => this * m;

  /// Returns this point divided by m (method form, Java compatibility).
  S2Point div(double m) => this / m;

  /// Returns the vector dot product of this with that.
  double dotProd(S2Point that) => x * that.x + y * that.y + z * that.z;

  /// Returns the vector cross product of this with that.
  S2Point crossProd(S2Point that) => S2Point(
        y * that.z - z * that.y,
        z * that.x - x * that.z,
        x * that.y - y * that.x,
      );

  /// Returns the vector magnitude.
  double get norm => math.sqrt(norm2);

  /// Returns the square of the vector magnitude.
  double get norm2 => x * x + y * y + z * z;

  /// Returns a copy rescaled to be unit-length, or zero if norm is zero.
  S2Point normalize() {
    final n = norm;
    if (n != 0) {
      return this * (1.0 / n);
    }
    return S2Point.zero;
  }

  /// Returns the component-wise absolute value.
  S2Point fabs() => S2Point(x.abs(), y.abs(), z.abs());

  /// Returns a vector orthogonal to this one.
  S2Point ortho() {
    switch (largestAbsComponent) {
      case 1:
        return crossProd(xPos).normalize();
      case 2:
        return crossProd(yPos).normalize();
      default:
        return crossProd(zPos).normalize();
    }
  }

  /// Returns the index of the largest component by absolute value.
  int get largestAbsComponent => largestAbsComponentFromCoords(x, y, z);

  /// Static method to find the largest component by absolute value.
  static int largestAbsComponentFromCoords(double x, double y, double z) {
    final absX = x.abs();
    final absY = y.abs();
    final absZ = z.abs();
    return (absX > absY) ? ((absX > absZ) ? 0 : 2) : ((absY > absZ) ? 1 : 2);
  }

  /// Returns the norm of the cross product.
  double crossProdNorm(S2Point that) {
    final cx = y * that.z - z * that.y;
    final cy = z * that.x - x * that.z;
    final cz = x * that.y - y * that.x;
    return math.sqrt(cx * cx + cy * cy + cz * cz);
  }

  /// Returns the angle between this and that in radians.
  double angle(S2Point that) => math.atan2(crossProdNorm(that), dotProd(that));

  /// Returns the 3D Cartesian distance between this and that.
  double getDistance(S2Point that) => math.sqrt(getDistance2(that));

  /// Returns the squared 3D Cartesian distance between this and that.
  double getDistance2(S2Point that) {
    final dx = x - that.x;
    final dy = y - that.y;
    final dz = z - that.z;
    return dx * dx + dy * dy + dz * dz;
  }

  /// Returns true if this point is less than that point.
  bool lessThan(S2Point that) {
    if (x < that.x) return true;
    if (that.x < x) return false;
    if (y < that.y) return true;
    if (that.y < y) return false;
    return z < that.z;
  }

  /// Compares components within margin.
  bool aequal(S2Point that, double margin) {
    return (x - that.x).abs() < margin &&
        (y - that.y).abs() < margin &&
        (z - that.z).abs() < margin;
  }

  /// Returns the scalar triple product a.dot(b.cross(c)).
  static double scalarTripleProduct(S2Point a, S2Point b, S2Point c) {
    final cx = b.y * c.z - b.z * c.y;
    final cy = b.z * c.x - b.x * c.z;
    final cz = b.x * c.y - b.y * c.x;
    return a.x * cx + a.y * cy + a.z * cz;
  }

  /// Rotates this point around axis by radians.
  S2Point rotate(S2Point axis, double radians) {
    final n = normalize();
    final a = axis.normalize();
    final center = a * n.dotProd(a);
    final axisToCenter = n - center;
    return (axisToCenter * math.cos(radians) + a.crossProd(n) * math.sin(radians) + center)
        .normalize();
  }

  @override
  bool operator ==(Object other) {
    if (other is S2Point) {
      return x == other.x && y == other.y && z == other.z;
    }
    return false;
  }

  @override
  int get hashCode {
    var value = 17;
    value = 37 * value + x.abs().hashCode;
    value = 37 * value + y.abs().hashCode;
    value = 37 * value + z.abs().hashCode;
    return value;
  }

  @override
  int compareTo(S2Point other) {
    return lessThan(other) ? -1 : (this == other ? 0 : 1);
  }

  @override
  String toString() => '($x, $y, $z)';

  /// Returns a string representation of this point in degrees (lat:lng format).
  String toDegreesString() {
    // Convert from 3D coordinates to lat/lng in degrees
    final lat = math.atan2(z, math.sqrt(x * x + y * y)) * 180.0 / math.pi;
    final lng = math.atan2(y, x) * 180.0 / math.pi;
    return '${lat.toStringAsFixed(7)}:${lng.toStringAsFixed(7)}';
  }

  /// Returns a component by index (0=x, 1=y, 2=z). Used by Matrix operations.
  double get(int index) => this[index];

  /// Returns true if this point is approximately equal to [p].
  /// This is used for containment tests where exact equality would fail
  /// due to floating point precision.
  bool containsPoint(S2Point p) => this == p;
}
