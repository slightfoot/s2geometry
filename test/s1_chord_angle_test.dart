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

/// Tests for S1ChordAngle.
/// Ported from S1ChordAngleTest.java
library;

import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:s2geometry/s2geometry.dart';

import 'geometry_test_case.dart';

void main() {
  group('S1ChordAngle', () {
    test('testFromLength2', () {
      assertExactly(0.0, S1ChordAngle.fromLength2(0).degrees);
      assertAlmostEquals(60.0, S1ChordAngle.fromLength2(1).degrees);
      assertAlmostEquals(90.0, S1ChordAngle.fromLength2(2).degrees);
      assertExactly(180.0, S1ChordAngle.fromLength2(4).degrees);
      assertExactly(180.0, S1ChordAngle.fromLength2(5).degrees);
    });

    test('testZero', () {
      expect(S1ChordAngle.ZERO.toAngle(), equals(S1Angle.zero));
    });

    test('testStraight', () {
      expect(S1ChordAngle.STRAIGHT.toAngle(), equals(S1Angle.degrees(180)));
    });

    test('testRight', () {
      expect(S1ChordAngle.RIGHT.degrees, closeTo(90.0, Platform.ulp(90.0)));
    });

    test('testInfinity', () {
      expect(S1ChordAngle.STRAIGHT.compareTo(S1ChordAngle.INFINITY) < 0, isTrue);
      expect(S1ChordAngle.INFINITY.toAngle(), equals(S1Angle.infinity));
    });

    test('testNegative', () {
      expect(S1ChordAngle.NEGATIVE.compareTo(S1ChordAngle.ZERO) < 0, isTrue);
      expect(S1ChordAngle.NEGATIVE.toAngle().compareTo(S1Angle.zero) < 0, isTrue);
    });

    test('testEquals', () {
      final angles = [
        S1ChordAngle.NEGATIVE,
        S1ChordAngle.ZERO,
        S1ChordAngle.STRAIGHT,
        S1ChordAngle.INFINITY
      ];
      for (var i = 0; i < angles.length; ++i) {
        for (var j = 0; j < angles.length; ++j) {
          expect(identical(angles[i], angles[j]), equals(angles[i] == angles[j]));
        }
      }
    });

    test('testPredicates', () {
      expect(S1ChordAngle.ZERO.isZero, isTrue);
      expect(S1ChordAngle.ZERO.isNegative, isFalse);
      expect(S1ChordAngle.ZERO.isSpecial, isFalse);
      expect(S1ChordAngle.STRAIGHT.isSpecial, isFalse);
      expect(S1ChordAngle.NEGATIVE.isNegative, isTrue);
      expect(S1ChordAngle.NEGATIVE.isSpecial, isTrue);
      expect(S1ChordAngle.INFINITY.isInfinity, isTrue);
      expect(S1ChordAngle.INFINITY.isSpecial, isTrue);
    });

    test('testToFromS1Angle', () {
      assertExactly(0.0, S1ChordAngle.fromS1Angle(S1Angle.zero).toAngle().radians);
      assertExactly(4.0, S1ChordAngle.fromS1Angle(S1Angle.radians(math.pi)).getLength2());
      assertExactly(math.pi, S1ChordAngle.fromS1Angle(S1Angle.radians(math.pi)).toAngle().radians);
      expect(S1ChordAngle.fromS1Angle(S1Angle.infinity).toAngle(), equals(S1Angle.infinity));
      expect(S1ChordAngle.fromS1Angle(S1Angle.radians(double.infinity)).toAngle(),
          equals(S1Angle.infinity));
      expect(S1ChordAngle.fromS1Angle(S1Angle.radians(-1)).toAngle().radians < 0.0, isTrue);
      assertAlmostEquals(1.0, S1ChordAngle.fromS1Angle(S1Angle.radians(1.0)).toAngle().radians);
    });

    test('testSuccessor', () {
      expect(S1ChordAngle.NEGATIVE.successor, equals(S1ChordAngle.ZERO));
      expect(S1ChordAngle.STRAIGHT.successor, equals(S1ChordAngle.INFINITY));
      expect(S1ChordAngle.INFINITY.successor, equals(S1ChordAngle.INFINITY));
      var x = S1ChordAngle.NEGATIVE;
      for (var i = 0; i < 10; ++i) {
        expect(x.compareTo(x.successor) < 0, isTrue);
        x = x.successor;
      }
    });

    test('testPredecessor', () {
      expect(S1ChordAngle.INFINITY.predecessor, equals(S1ChordAngle.STRAIGHT));
      expect(S1ChordAngle.ZERO.predecessor, equals(S1ChordAngle.NEGATIVE));
      expect(S1ChordAngle.NEGATIVE.predecessor, equals(S1ChordAngle.NEGATIVE));
      var x = S1ChordAngle.INFINITY;
      for (var i = 0; i < 10; ++i) {
        expect(x.compareTo(x.predecessor) > 0, isTrue);
        x = x.predecessor;
      }
    });

    test('testArithmetic', () {
      final zero = S1ChordAngle.ZERO;
      final degree30 = S1ChordAngle.fromS1Angle(S1Angle.degrees(30));
      final degree60 = S1ChordAngle.fromS1Angle(S1Angle.degrees(60));
      final degree90 = S1ChordAngle.fromS1Angle(S1Angle.degrees(90));
      final degree120 = S1ChordAngle.fromS1Angle(S1Angle.degrees(120));
      final degree180 = S1ChordAngle.STRAIGHT;

      assertExactly(0.0, S1ChordAngle.add(zero, zero).degrees);
      assertExactly(0.0, S1ChordAngle.sub(zero, zero).degrees);
      assertExactly(0.0, S1ChordAngle.sub(degree60, degree60).degrees);
      assertExactly(0.0, S1ChordAngle.sub(degree180, degree180).degrees);
      assertExactly(0.0, S1ChordAngle.sub(zero, degree60).degrees);
      assertExactly(0.0, S1ChordAngle.sub(degree30, degree90).degrees);
      assertAlmostEquals(60.0, S1ChordAngle.add(degree60, zero).degrees);
      assertAlmostEquals(60.0, S1ChordAngle.sub(degree60, zero).degrees);
      assertAlmostEquals(60.0, S1ChordAngle.add(zero, degree60).degrees);
      assertAlmostEquals(90.0, S1ChordAngle.add(degree30, degree60).degrees);
      assertAlmostEquals(90.0, S1ChordAngle.add(degree60, degree30).degrees);
      assertAlmostEquals(60.0, S1ChordAngle.sub(degree90, degree30).degrees);
      assertAlmostEquals(30.0, S1ChordAngle.sub(degree90, degree60).degrees);
      assertExactly(180.0, S1ChordAngle.add(degree180, zero).degrees);
      assertExactly(180.0, S1ChordAngle.sub(degree180, zero).degrees);
      assertExactly(180.0, S1ChordAngle.add(degree90, degree90).degrees);
      assertExactly(180.0, S1ChordAngle.add(degree120, degree90).degrees);
      assertExactly(180.0, S1ChordAngle.add(degree120, degree120).degrees);
      assertExactly(180.0, S1ChordAngle.add(degree30, degree180).degrees);
      assertExactly(180.0, S1ChordAngle.add(degree180, degree180).degrees);
    });

    test('testArithmeticPrecision', () {
      final kEps = S1ChordAngle.fromRadians(1e-15);
      final k90 = S1ChordAngle.RIGHT;
      final k90MinusEps = S1ChordAngle.sub(k90, kEps);
      final k90PlusEps = S1ChordAngle.add(k90, kEps);

      final kMaxError = 2 * S2.dblEpsilon;
      assertDoubleNear(k90MinusEps.radians, S2.mPi2 - kEps.radians, kMaxError);
      assertDoubleNear(k90PlusEps.radians, S2.mPi2 + kEps.radians, kMaxError);
      assertDoubleNear(
          S1ChordAngle.sub(k90, k90MinusEps).getLength2(), kEps.getLength2(), kMaxError);
      assertDoubleNear(S1ChordAngle.sub(k90, k90MinusEps).radians, kEps.radians, kMaxError);
      assertDoubleNear(S1ChordAngle.sub(k90PlusEps, k90).radians, kEps.radians, kMaxError);
      assertDoubleNear(S1ChordAngle.add(k90MinusEps, kEps).radians, S2.mPi2, kMaxError);
    });

    test('testTrigonometry', () {
      final int iters = 20;
      for (var iter = 0; iter <= iters; ++iter) {
        final radians = math.pi * iter / iters;
        final angle = S1ChordAngle.fromS1Angle(S1Angle.radians(radians));
        expect(S1ChordAngle.sin(angle), closeTo(math.sin(radians), 1e-15));
        expect(S1ChordAngle.cos(angle), closeTo(math.cos(radians), 1e-15));
        // Since tan(x) is unbounded near Pi/4, we map the result back to an angle
        expect(math.atan(S1ChordAngle.tan(angle)), closeTo(math.atan(math.tan(radians)), 1e-15));
      }

      // Unlike S1Angle, S1ChordAngle can represent 90 and 180 degrees exactly.
      final angle90 = S1ChordAngle.fromLength2(2);
      final angle180 = S1ChordAngle.fromLength2(4);
      assertExactly(1.0, S1ChordAngle.sin(angle90));
      assertExactly(0.0, S1ChordAngle.cos(angle90));
      assertExactly(double.infinity, S1ChordAngle.tan(angle90));
      assertExactly(0.0, S1ChordAngle.sin(angle180));
      assertExactly(-1.0, S1ChordAngle.cos(angle180));
      assertExactly(-0.0, S1ChordAngle.tan(angle180));
    });

    test('testPlusError', () {
      expect(S1ChordAngle.NEGATIVE.plusError(5), equals(S1ChordAngle.NEGATIVE));
      expect(S1ChordAngle.INFINITY.plusError(-5), equals(S1ChordAngle.INFINITY));
      expect(S1ChordAngle.STRAIGHT.plusError(5), equals(S1ChordAngle.STRAIGHT));
      expect(S1ChordAngle.ZERO.plusError(-5), equals(S1ChordAngle.ZERO));
      expect(S1ChordAngle.fromLength2(1.25), equals(S1ChordAngle.fromLength2(1).plusError(0.25)));
      expect(S1ChordAngle.fromLength2(0.75), equals(S1ChordAngle.fromLength2(1).plusError(-0.25)));
    });

    test('testHashCodeZero', () {
      final positive0 = S1ChordAngle.fromLength2(0);
      final negative0 = S1ChordAngle.fromLength2(-0.0);

      expect(positive0, equals(negative0));
      expect(positive0.hashCode, equals(negative0.hashCode));
    });

    test('testHashCodeDifferent', () {
      final zero = S1ChordAngle.fromLength2(0);
      final nonZero = S1ChordAngle.fromLength2(1);

      expect(zero, isNot(equals(nonZero)));
      expect(zero.hashCode != nonZero.hashCode, isTrue);
    });

    test('testFromPoints', () {
      final a = S2Point(1, 0, 0);
      final b = S2Point(0, 1, 0);
      final angle = S1ChordAngle.fromPoints(a, b);
      expect(angle.degrees, closeTo(90.0, 1e-10));
    });

    test('testFromPointsSamePoint', () {
      final a = S2Point(1, 0, 0);
      final angle = S1ChordAngle.fromPoints(a, a);
      expect(angle.isZero, isTrue);
    });

    test('testFactoryConstructor', () {
      final a = S2Point(1, 0, 0);
      final b = S2Point(0, 1, 0);
      final angle = S1ChordAngle(a, b);
      expect(angle.degrees, closeTo(90.0, 1e-10));
    });

    test('testFromDegrees', () {
      final angle = S1ChordAngle.fromDegrees(60);
      expect(angle.degrees, closeTo(60.0, 1e-10));
    });

    test('testIsStraight', () {
      expect(S1ChordAngle.STRAIGHT.isStraight, isTrue);
      expect(S1ChordAngle.ZERO.isStraight, isFalse);
    });

    test('testIsValid', () {
      expect(S1ChordAngle.ZERO.isValid, isTrue);
      expect(S1ChordAngle.RIGHT.isValid, isTrue);
      expect(S1ChordAngle.STRAIGHT.isValid, isTrue);
      expect(S1ChordAngle.NEGATIVE.isValid, isTrue);
      expect(S1ChordAngle.INFINITY.isValid, isTrue);
    });

    test('testComparison', () {
      final small = S1ChordAngle.fromDegrees(30);
      final large = S1ChordAngle.fromDegrees(60);

      expect(small.lessThan(large), isTrue);
      expect(large.lessThan(small), isFalse);
      expect(large.greaterThan(small), isTrue);
      expect(small.greaterThan(large), isFalse);
      expect(small.lessOrEquals(large), isTrue);
      expect(small.lessOrEquals(small), isTrue);
      expect(large.greaterOrEquals(small), isTrue);
      expect(large.greaterOrEquals(large), isTrue);
    });

    test('testMinMax', () {
      final small = S1ChordAngle.fromDegrees(30);
      final large = S1ChordAngle.fromDegrees(60);

      expect(S1ChordAngle.min(small, large), equals(small));
      expect(S1ChordAngle.min(large, small), equals(small));
      expect(S1ChordAngle.max(small, large), equals(large));
      expect(S1ChordAngle.max(large, small), equals(large));
    });

    test('testSin2', () {
      final angle = S1ChordAngle.fromDegrees(90);
      // sin²(90°) = 1
      expect(S1ChordAngle.sin2(angle), closeTo(1.0, 1e-10));
    });

    test('testOperatorPlus', () {
      final a = S1ChordAngle.fromDegrees(30);
      final b = S1ChordAngle.fromDegrees(40);
      final result = a + b;
      expect(result.degrees, closeTo(70.0, 0.1));
    });

    test('testOperatorPlusSpecial', () {
      expect(S1ChordAngle.NEGATIVE + S1ChordAngle.ZERO, equals(S1ChordAngle.NEGATIVE));
      expect(S1ChordAngle.ZERO + S1ChordAngle.NEGATIVE, equals(S1ChordAngle.NEGATIVE));
      expect(S1ChordAngle.INFINITY + S1ChordAngle.ZERO, equals(S1ChordAngle.INFINITY));
      expect(S1ChordAngle.ZERO + S1ChordAngle.INFINITY, equals(S1ChordAngle.INFINITY));
    });

    test('testOperatorPlusStraight', () {
      final a = S1ChordAngle.fromDegrees(100);
      final b = S1ChordAngle.fromDegrees(100);
      final result = a + b;
      expect(result, equals(S1ChordAngle.STRAIGHT));
    });

    test('testOperatorMinus', () {
      final a = S1ChordAngle.fromDegrees(60);
      final b = S1ChordAngle.fromDegrees(30);
      final result = a - b;
      expect(result.degrees, closeTo(30.0, 0.1));
    });

    test('testOperatorMinusSpecial', () {
      expect(S1ChordAngle.NEGATIVE - S1ChordAngle.ZERO, equals(S1ChordAngle.NEGATIVE));
      expect(S1ChordAngle.ZERO - S1ChordAngle.NEGATIVE, equals(S1ChordAngle.NEGATIVE));
      expect(S1ChordAngle.INFINITY - S1ChordAngle.ZERO, equals(S1ChordAngle.INFINITY));
      expect(S1ChordAngle.ZERO - S1ChordAngle.INFINITY, equals(S1ChordAngle.INFINITY));
    });

    test('testOperatorMinusZero', () {
      final a = S1ChordAngle.fromDegrees(30);
      final b = S1ChordAngle.fromDegrees(60);
      final result = a - b;
      expect(result.isZero, isTrue);
    });

    test('testToString', () {
      expect(S1ChordAngle.NEGATIVE.toString(), equals('NEGATIVE'));
      expect(S1ChordAngle.ZERO.toString(), equals('ZERO'));
      expect(S1ChordAngle.STRAIGHT.toString(), equals('STRAIGHT'));
      expect(S1ChordAngle.INFINITY.toString(), equals('INFINITY'));
      expect(S1ChordAngle.fromDegrees(45).toString(), contains('45'));
    });

    test('testGetS1AngleConstructorMaxError', () {
      final angle = S1ChordAngle.fromDegrees(60);
      expect(angle.s1AngleConstructorMaxError, greaterThanOrEqualTo(0));
      expect(angle.getS1AngleConstructorMaxError(), equals(angle.s1AngleConstructorMaxError));
    });

    test('testGetS2PointConstructorMaxError', () {
      final angle = S1ChordAngle.fromDegrees(60);
      expect(angle.s2PointConstructorMaxError, greaterThanOrEqualTo(0));
      expect(angle.getS2PointConstructorMaxError(), equals(angle.s2PointConstructorMaxError));
    });

    test('testLength2Getter', () {
      final angle = S1ChordAngle.fromDegrees(60);
      expect(angle.length2, equals(angle.getLength2()));
      expect(angle.length2, closeTo(1.0, 0.01)); // 60 degrees has length2 ~= 1
    });

    test('testRadiansGetter', () {
      final angle = S1ChordAngle.fromDegrees(90);
      expect(angle.radians, closeTo(math.pi / 2, 1e-10));
    });

    test('testEqualityWithNonChordAngle', () {
      final angle = S1ChordAngle.fromDegrees(60);
      expect(angle == "not a chord angle", isFalse);
    });
  });
}
