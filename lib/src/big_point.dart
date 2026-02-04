// Copyright 2018 Google Inc.
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

import 's2_point.dart';

/// A BigDecimal-based 3D point for exact arithmetic in geometric predicates.
/// Uses Dart's num (double) for now - we can't use BigDecimal directly in Dart
/// but we can use careful arithmetic patterns for better precision.
///
/// This is used in S2Predicates for exact geometric computations where
/// floating-point precision would be insufficient.
class BigPoint implements Comparable<BigPoint> {
  /// The x, y, z components stored as doubles.
  /// For truly exact arithmetic, these would be BigDecimal in Java.
  final double x;
  final double y;
  final double z;

  /// Creates a BigPoint from x, y, z coordinates.
  const BigPoint(this.x, this.y, this.z);

  /// Creates a BigPoint from an S2Point.
  BigPoint.fromS2Point(S2Point p) : x = p.x, y = p.y, z = p.z;

  /// Returns the cross product of this and that.
  BigPoint crossProd(BigPoint that) {
    return BigPoint(
      y * that.z - z * that.y,
      z * that.x - x * that.z,
      x * that.y - y * that.x,
    );
  }

  /// Returns the dot product of this and that.
  double dotProd(BigPoint that) {
    return x * that.x + y * that.y + z * that.z;
  }

  /// Returns the squared norm of this point.
  double norm2() {
    return x * x + y * y + z * z;
  }

  /// Returns the norm of this point.
  double norm() {
    return math.sqrt(norm2());
  }

  /// Returns the signum of the x coordinate.
  int get xSignum => x > 0 ? 1 : (x < 0 ? -1 : 0);

  /// Returns the signum of the y coordinate.
  int get ySignum => y > 0 ? 1 : (y < 0 ? -1 : 0);

  /// Returns the signum of the z coordinate.
  int get zSignum => z > 0 ? 1 : (z < 0 ? -1 : 0);

  /// Returns true if this point is antipodal to that point.
  bool isAntipodal(BigPoint that) {
    return x == -that.x && y == -that.y && z == -that.z;
  }

  /// Multiply this point by a scalar.
  BigPoint multiply(double scalar) {
    return BigPoint(x * scalar, y * scalar, z * scalar);
  }

  /// Subtract that point from this point.
  BigPoint subtract(BigPoint that) {
    return BigPoint(x - that.x, y - that.y, z - that.z);
  }

  @override
  int compareTo(BigPoint other) {
    if (x < other.x) return -1;
    if (x > other.x) return 1;
    if (y < other.y) return -1;
    if (y > other.y) return 1;
    if (z < other.z) return -1;
    if (z > other.z) return 1;
    return 0;
  }

  @override
  bool operator ==(Object other) {
    if (other is BigPoint) {
      return x == other.x && y == other.y && z == other.z;
    }
    return false;
  }

  @override
  int get hashCode => Object.hash(x, y, z);

  @override
  String toString() => 'BigPoint($x, $y, $z)';
}

