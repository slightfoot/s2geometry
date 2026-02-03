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

import 's2_point.dart';

/// This class represents a one-dimensional angle (as opposed to a two-dimensional
/// solid angle). It has methods for converting angles to or from radians, degrees,
/// and the E5/E6/E7 representations (degrees multiplied by 1e5/1e6/1e7).
class S1Angle implements Comparable<S1Angle> {
  /// An angle larger than any finite angle.
  static final S1Angle infinity = S1Angle._(double.infinity);

  /// An explicit shorthand for the zero angle.
  static final S1Angle zero = S1Angle._(0);

  final double _radians;

  /// Private constructor.
  const S1Angle._(this._radians);

  /// Returns a new S1Angle from radians.
  const S1Angle.radians(double radians) : _radians = radians;

  /// Returns the angle in radians.
  double get radians => _radians;

  /// Returns a new S1Angle from degrees.
  factory S1Angle.degrees(double degrees) {
    return S1Angle._(degrees * (math.pi / 180));
  }

  /// Returns the angle in degrees.
  double get degrees => _radians * (180 / math.pi);

  /// Returns a new S1Angle from tens of microdegrees.
  factory S1Angle.e5(int e5) => S1Angle.degrees(e5 * 1e-5);

  /// Returns angle in tens of microdegrees, rounded.
  int get e5 => (degrees * 1e5).round();

  /// Returns a new S1Angle from microdegrees.
  factory S1Angle.e6(int e6) => S1Angle.degrees(e6 * 1e-6);

  /// Returns angle in microdegrees, rounded.
  int get e6 => (degrees * 1e6).round();

  /// Returns a new S1Angle from tenths of a microdegree.
  factory S1Angle.e7(int e7) => S1Angle.degrees(e7 * 1e-7);

  /// Returns angle in tenths of a microdegree, rounded.
  int get e7 => (degrees * 1e7).round();

  /// Returns the angle between two points on the unit sphere.
  factory S1Angle.fromPoints(S2Point x, S2Point y) {
    return S1Angle._(x.angle(y));
  }

  /// Returns true if this angle is zero.
  bool get isZero => _radians == 0;

  @override
  bool operator ==(Object other) {
    if (other is S1Angle) {
      return _radians == other._radians;
    }
    return false;
  }

  @override
  int get hashCode => _radians.hashCode;

  /// Returns true if this angle is less than that angle.
  bool operator <(S1Angle other) => _radians < other._radians;

  /// Returns true if this angle is greater than that angle.
  bool operator >(S1Angle other) => _radians > other._radians;

  /// Returns true if this angle is less than or equal to that angle.
  bool operator <=(S1Angle other) => _radians <= other._radians;

  /// Returns true if this angle is greater than or equal to that angle.
  bool operator >=(S1Angle other) => _radians >= other._radians;

  /// Returns the larger of two angles.
  static S1Angle max(S1Angle left, S1Angle right) {
    return right > left ? right : left;
  }

  /// Returns the smaller of two angles.
  static S1Angle min(S1Angle left, S1Angle right) {
    return right > left ? left : right;
  }

  /// Returns the distance along a sphere of the given radius.
  double distance(double radius) => _radians * radius;

  /// Returns an S1Angle whose angle is the absolute value of this.
  S1Angle abs() => S1Angle._(_radians.abs());

  /// Returns an S1Angle whose angle is the negation of this.
  S1Angle operator -() => S1Angle._(-_radians);

  /// Returns an S1Angle whose angle is this + a.
  S1Angle operator +(S1Angle a) => S1Angle._(_radians + a._radians);

  /// Returns an S1Angle whose angle is this - a.
  S1Angle operator -(S1Angle a) => S1Angle._(_radians - a._radians);

  /// Returns an S1Angle whose angle is this * m.
  S1Angle operator *(double m) => S1Angle._(_radians * m);

  /// Returns an S1Angle whose angle is this / d.
  S1Angle operator /(double d) => S1Angle._(_radians / d);

  /// Returns this.radians / other.radians.
  double divAngle(S1Angle other) => _radians / other._radians;

  /// Returns the trigonometric cosine of the angle.
  double get cos => math.cos(_radians);

  /// Returns the trigonometric sine of the angle.
  double get sin => math.sin(_radians);

  /// Returns the trigonometric tangent of the angle.
  double get tan => math.tan(_radians);

  /// Returns the angle normalized to the range (-180, 180] degrees.
  S1Angle normalize() {
    if (_radians > -math.pi && _radians <= math.pi) {
      return this;
    }
    var normalized = _radians % (2 * math.pi);
    if (normalized <= -math.pi) {
      normalized = math.pi;
    } else if (normalized > math.pi) {
      normalized -= 2 * math.pi;
    }
    return S1Angle._(normalized);
  }

  @override
  String toString() => '${degrees}d';

  @override
  int compareTo(S1Angle other) {
    return _radians < other._radians ? -1 : (_radians > other._radians ? 1 : 0);
  }
}

