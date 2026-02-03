// Copyright 2014 Google Inc. All Rights Reserved.
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
import 's1_angle.dart';
import 's2_point.dart';

/// S1ChordAngle represents the angle subtended by a chord (the straight line
/// segment connecting two points on the unit sphere).
/// 
/// It is very efficient for computing and comparing distances, but unlike
/// S1Angle it is only capable of representing angles between 0 and Pi radians.
class S1ChordAngle implements Comparable<S1ChordAngle> {
  /// Maximum squared chord length.
  static const double maxLength2 = 4.0;

  /// The zero chord angle (lowercase).
  static final S1ChordAngle zero = S1ChordAngle._(0);

  /// The zero chord angle (uppercase, Java compatibility).
  static final S1ChordAngle ZERO = zero;

  /// The chord angle of 90 degrees (lowercase).
  static final S1ChordAngle right = S1ChordAngle._(2);

  /// The chord angle of 90 degrees (uppercase, Java compatibility).
  static final S1ChordAngle RIGHT = right;

  /// The chord angle of 180 degrees (maximum finite chord angle, lowercase).
  static final S1ChordAngle straight = S1ChordAngle._(maxLength2);

  /// The chord angle of 180 degrees (uppercase, Java compatibility).
  static final S1ChordAngle STRAIGHT = straight;

  /// A chord angle larger than any finite chord angle (lowercase).
  static final S1ChordAngle infinity = S1ChordAngle._(double.infinity);

  /// A chord angle larger than any finite chord angle (uppercase, Java compatibility).
  static final S1ChordAngle INFINITY = infinity;

  /// A chord angle smaller than zero (lowercase).
  static final S1ChordAngle negative = S1ChordAngle._(-1);

  /// A chord angle smaller than zero (uppercase, Java compatibility).
  static final S1ChordAngle NEGATIVE = negative;

  final double _length2;

  S1ChordAngle._(this._length2);

  /// Constructs the chord angle between two points on the unit sphere.
  /// This is the factory constructor for Java compatibility (new S1ChordAngle(x, y)).
  factory S1ChordAngle(S2Point x, S2Point y) = S1ChordAngle.fromPoints;

  /// Constructs the chord angle between two points on the unit sphere.
  S1ChordAngle.fromPoints(S2Point x, S2Point y)
      : _length2 = math.min(maxLength2, x.getDistance2(y));

  /// Creates a chord angle from an S1Angle.
  factory S1ChordAngle.fromS1Angle(S1Angle angle) {
    if (angle.radians < 0) return negative;
    if (angle == S1Angle.infinity) return infinity;
    final length = 2 * math.sin(0.5 * math.min(math.pi, angle.radians));
    return S1ChordAngle._(length * length);
  }

  /// Creates from radians.
  factory S1ChordAngle.fromRadians(double radians) =>
      S1ChordAngle.fromS1Angle(S1Angle.radians(radians));

  /// Creates from degrees.
  factory S1ChordAngle.fromDegrees(double degrees) =>
      S1ChordAngle.fromS1Angle(S1Angle.degrees(degrees));

  /// Creates from squared chord length.
  static S1ChordAngle fromLength2(double length2) =>
      S1ChordAngle._(math.min(maxLength2, length2));

  /// Returns the squared chord length.
  double get length2 => _length2;

  /// Returns the squared chord length (Java compatibility).
  double getLength2() => _length2;

  /// Returns true if zero.
  bool get isZero => _length2 == 0;

  /// Returns true if 180 degrees.
  bool get isStraight => _length2 == maxLength2;

  /// Returns true if negative.
  bool get isNegative => _length2 < 0;

  /// Returns true if infinity.
  bool get isInfinity => _length2 == double.infinity;

  /// Returns true if negative or infinity.
  bool get isSpecial => isNegative || isInfinity;

  /// Returns true if valid.
  bool get isValid =>
      (_length2 >= 0 && _length2 <= maxLength2) || isNegative || isInfinity;

  /// Returns true if less than other.
  bool lessThan(S1ChordAngle other) => _length2 < other._length2;

  /// Returns true if greater than other.
  bool greaterThan(S1ChordAngle other) => _length2 > other._length2;

  /// Returns true if less than or equal to other.
  bool lessOrEquals(S1ChordAngle other) => _length2 <= other._length2;

  /// Returns true if greater than or equal to other.
  bool greaterOrEquals(S1ChordAngle other) => _length2 >= other._length2;

  /// Converts to S1Angle.
  S1Angle toAngle() {
    if (isNegative) return S1Angle.radians(-1);
    if (isInfinity) return S1Angle.infinity;
    return S1Angle.radians(2 * math.asin(0.5 * math.sqrt(_length2)));
  }

  /// Returns the radians approximation.
  double get radians => toAngle().radians;

  /// Returns the degrees approximation.
  double get degrees => toAngle().degrees;

  /// Returns the smallest representable chord angle larger than this.
  S1ChordAngle get successor {
    if (_length2 >= maxLength2) return infinity;
    if (_length2 < 0.0) return zero;
    return S1ChordAngle._(Platform.nextAfter(_length2, 10.0));
  }

  /// Returns the largest representable chord angle smaller than this.
  S1ChordAngle get predecessor {
    if (_length2 <= 0.0) return negative;
    if (_length2 > maxLength2) return straight;
    return S1ChordAngle._(Platform.nextAfter(_length2, -10.0));
  }

  /// Returns the sum of two chord angles (capped at 180 degrees).
  static S1ChordAngle add(S1ChordAngle a, S1ChordAngle b) {
    assert(!a.isSpecial && !b.isSpecial);
    final a2 = a._length2;
    final b2 = b._length2;
    if (b2 == 0) return a;
    if (a2 + b2 >= maxLength2) return straight;
    final x = a2 * (1 - 0.25 * b2);
    final y = b2 * (1 - 0.25 * a2);
    return S1ChordAngle._(math.min(maxLength2, x + y + 2 * math.sqrt(x * y)));
  }

  /// Returns the difference of two chord angles (floored at zero).
  static S1ChordAngle sub(S1ChordAngle a, S1ChordAngle b) {
    assert(!a.isSpecial && !b.isSpecial);
    if (b._length2 == 0) return a;
    if (a._length2 <= b._length2) return zero;
    final x = a._length2 * (1 - 0.25 * b._length2);
    final y = b._length2 * (1 - 0.25 * a._length2);
    final c = math.max(0.0, math.sqrt(x) - math.sqrt(y));
    return S1ChordAngle._(c * c);
  }

  /// Returns the smaller of the two chord angles.
  static S1ChordAngle min(S1ChordAngle a, S1ChordAngle b) =>
      a._length2 <= b._length2 ? a : b;

  /// Returns the larger of the two chord angles.
  static S1ChordAngle max(S1ChordAngle a, S1ChordAngle b) =>
      a._length2 > b._length2 ? a : b;

  /// Returns sin²(angle).
  static double sin2(S1ChordAngle a) {
    assert(!a.isSpecial);
    return a._length2 * (1 - 0.25 * a._length2);
  }

  /// Returns sin(angle).
  static double sin(S1ChordAngle a) => math.sqrt(sin2(a));

  /// Returns cos(angle).
  static double cos(S1ChordAngle a) {
    assert(!a.isSpecial);
    return 1 - 0.5 * a._length2;
  }

  /// Returns tan(angle).
  static double tan(S1ChordAngle a) => sin(a) / cos(a);

  /// Returns a chord angle adjusted by the given error bound.
  S1ChordAngle plusError(double error) {
    if (isSpecial) return this;
    return fromLength2(math.max(0.0, math.min(maxLength2, _length2 + error)));
  }

  /// Returns the error in fromS1Angle.
  double get s1AngleConstructorMaxError => 1.5 * Platform.dblEpsilon * _length2;

  /// Returns the error in fromS1Angle (Java compatibility).
  double getS1AngleConstructorMaxError() => s1AngleConstructorMaxError;

  /// Returns the error in fromPoints.
  double get s2PointConstructorMaxError =>
      (4.5 * Platform.dblEpsilon * _length2) +
      (16 * Platform.dblEpsilon * Platform.dblEpsilon);

  /// Returns the error in fromPoints (Java compatibility).
  double getS2PointConstructorMaxError() => s2PointConstructorMaxError;

  @override
  bool operator ==(Object other) {
    if (other is S1ChordAngle) return _length2 == other._length2;
    return false;
  }

  @override
  int get hashCode => _length2 == 0 ? 0 : _length2.hashCode;

  @override
  int compareTo(S1ChordAngle other) => _length2.compareTo(other._length2);

  /// Returns the sum of two chord angles (addition).
  S1ChordAngle operator +(S1ChordAngle other) {
    // Handle special cases
    if (isNegative || other.isNegative) return negative;
    if (isInfinity || other.isInfinity) return infinity;

    // Sum of chord angles is more complex. We need to convert to radians,
    // add, and convert back. This gives us an approximation.
    double sum = toAngle().radians + other.toAngle().radians;
    if (sum >= math.pi) return straight;
    return S1ChordAngle.fromS1Angle(S1Angle.radians(sum));
  }

  /// Returns the subtraction of two chord angles.
  S1ChordAngle operator -(S1ChordAngle other) {
    if (isNegative || other.isNegative) return negative;
    if (isInfinity || other.isInfinity) return infinity;

    double diff = toAngle().radians - other.toAngle().radians;
    if (diff < 0) return zero;
    return S1ChordAngle.fromS1Angle(S1Angle.radians(diff));
  }

  @override
  String toString() {
    if (_length2 == negative._length2) return 'NEGATIVE';
    if (_length2 == zero._length2) return 'ZERO';
    if (_length2 == straight._length2) return 'STRAIGHT';
    if (_length2 == infinity._length2) return 'INFINITY';
    return toAngle().toString();
  }
}

