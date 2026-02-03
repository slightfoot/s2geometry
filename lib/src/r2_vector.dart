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

/// R2Vector represents a vector in two-dimensional space.
/// It defines basic geometrical operations for 2D vectors.
class R2Vector {
  double x;
  double y;

  /// Constructs a new R2Vector at the origin [0,0].
  R2Vector.origin()
      : x = 0,
        y = 0;

  /// Constructs a new R2Vector from the given x and y coordinates.
  R2Vector(this.x, this.y);

  /// Constructs a new R2Vector from a coordinate array of length 2.
  /// This matches the Java constructor: new R2Vector(double[] coords).
  R2Vector.fromArray(List<double> coords)
      : x = coords[0],
        y = coords[1] {
    if (coords.length != 2) {
      throw ArgumentError('Points must have exactly 2 coordinates');
    }
  }

  /// Constructs a new R2Vector from a coordinate list of length 2.
  R2Vector.fromList(List<double> coords)
      : x = coords[0],
        y = coords[1] {
    if (coords.length != 2) {
      throw ArgumentError('Points must have exactly 2 coordinates');
    }
  }

  // Java-style getters for compatibility
  double getX() => x;
  double getY() => y;

  /// Returns the coordinate at the given index (0 for x, 1 for y).
  double operator [](int index) {
    if (index == 0) return x;
    if (index == 1) return y;
    throw RangeError.index(index, this, 'index', null, 2);
  }

  /// Sets the coordinate at the given index (0 for x, 1 for y).
  void operator []=(int index, double value) {
    if (index == 0) {
      x = value;
    } else if (index == 1) {
      y = value;
    } else {
      throw RangeError.index(index, this, 'index', null, 2);
    }
  }

  /// Sets the position from another vector.
  void setFrom(R2Vector v) {
    x = v.x;
    y = v.y;
  }

  /// Sets the position from the given coordinates.
  void set(double newX, double newY) {
    x = newX;
    y = newY;
  }

  /// Returns the vector sum of this and p.
  R2Vector operator +(R2Vector p) => R2Vector(x + p.x, y + p.y);

  /// Returns the vector difference of this and p.
  R2Vector operator -(R2Vector p) => R2Vector(x - p.x, y - p.y);

  /// Returns this vector scaled by m.
  R2Vector operator *(double m) => R2Vector(m * x, m * y);

  /// Returns this vector divided by m.
  R2Vector operator /(double m) => R2Vector(x / m, y / m);

  /// Returns the negation of this vector.
  R2Vector operator -() => R2Vector(-x, -y);

  /// Returns the vector magnitude.
  double get norm => math.sqrt(norm2);

  /// Returns the square of the vector magnitude.
  double get norm2 => x * x + y * y;

  /// Returns a new vector scaled to unit length, or a copy if magnitude was 0.
  R2Vector normalize() {
    final n = norm;
    if (n != 0) {
      return this * (1.0 / n);
    }
    return R2Vector(x, y);
  }

  /// Returns a new vector orthogonal to this one (counterclockwise).
  R2Vector ortho() => R2Vector(-y, x);

  /// Returns the dot product of this vector with that vector.
  double dotProd(R2Vector that) => x * that.x + y * that.y;

  /// Returns the cross product of this vector with that vector.
  double crossProd(R2Vector that) => x * that.y - y * that.x;

  /// Returns true if this vector is less than that vector.
  bool lessThan(R2Vector that) {
    if (x < that.x) return true;
    if (that.x < x) return false;
    return y < that.y;
  }

  // Java-style instance methods for compatibility
  /// Returns the vector sum of this and p (Java compatibility).
  R2Vector add(R2Vector p) => R2Vector(x + p.x, y + p.y);

  /// Returns the vector difference of this and p (Java compatibility).
  R2Vector sub(R2Vector p) => R2Vector(x - p.x, y - p.y);

  /// Returns this vector scaled by m (Java compatibility).
  R2Vector mul(double m) => R2Vector(m * x, m * y);

  // Static methods for Java compatibility
  /// Returns the vector sum of p1 and p2 (static, Java compatibility).
  static R2Vector addStatic(R2Vector p1, R2Vector p2) => R2Vector(p1.x + p2.x, p1.y + p2.y);

  /// Returns the vector difference of p1 and p2 (static, Java compatibility).
  static R2Vector subStatic(R2Vector p1, R2Vector p2) => R2Vector(p1.x - p2.x, p1.y - p2.y);

  /// Returns p scaled by m (static, Java compatibility).
  static R2Vector mulStatic(R2Vector p, double m) => R2Vector(m * p.x, m * p.y);

  @override
  bool operator ==(Object other) {
    if (other is R2Vector) {
      return x == other.x && y == other.y;
    }
    return false;
  }

  @override
  int get hashCode {
    var value = 17;
    value = 37 * value + x.abs().hashCode;
    value = 37 * value + y.abs().hashCode;
    return value;
  }

  @override
  String toString() => '($x, $y)';
}
