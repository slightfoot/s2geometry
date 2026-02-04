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

import 'package:s2geometry/s2geometry.dart';
import 'package:test/test.dart';

void main() {
  group('Platform', () {
    test('testDblEpsilon', () {
      // Verify epsilon is approximately correct
      expect(Platform.dblEpsilon, closeTo(2.22e-16, 1e-17));

      // Verify 1.0 + epsilon != 1.0
      expect(1.0 + Platform.dblEpsilon, isNot(equals(1.0)));

      // Verify 1.0 + epsilon/2 == 1.0 (within precision)
      expect(1.0 + Platform.dblEpsilon / 2, equals(1.0));
    });

    test('testIeeeRemainder', () {
      // Basic cases
      expect(Platform.ieeeRemainder(5.0, 3.0), closeTo(-1.0, 1e-10));
      expect(Platform.ieeeRemainder(10.0, 3.0), closeTo(1.0, 1e-10));

      // Remainder with pi
      expect(Platform.ieeeRemainder(math.pi, 2.0), closeTo(math.pi - 4.0, 1e-10));
    });

    test('testNextAfter', () {
      // From 0 towards positive
      final smallPos = Platform.nextAfter(0.0, 1.0);
      expect(smallPos, greaterThan(0.0));
      expect(smallPos, equals(double.minPositive));

      // From 0 towards negative
      final smallNeg = Platform.nextAfter(0.0, -1.0);
      expect(smallNeg, lessThan(0.0));

      // From 1 towards 2
      final next = Platform.nextAfter(1.0, 2.0);
      expect(next, greaterThan(1.0));
      expect(next - 1.0, lessThan(1e-14));

      // From 1 towards 0
      final prev = Platform.nextAfter(1.0, 0.0);
      expect(prev, lessThan(1.0));
      expect(1.0 - prev, lessThan(1e-14));

      // NaN cases
      expect(Platform.nextAfter(double.nan, 1.0).isNaN, isTrue);
      expect(Platform.nextAfter(1.0, double.nan).isNaN, isTrue);

      // Same value
      expect(Platform.nextAfter(1.0, 1.0), equals(1.0));
    });

    test('testNumberOfLeadingZeros', () {
      expect(Platform.numberOfLeadingZeros(0), equals(64));
      expect(Platform.numberOfLeadingZeros(1), equals(63));
      // Positive values work correctly
      expect(Platform.numberOfLeadingZeros(0x0100000000000000), equals(7));
      expect(Platform.numberOfLeadingZeros(0x7FFFFFFFFFFFFFFF), equals(1));
    });

    test('testNumberOfTrailingZeros', () {
      expect(Platform.numberOfTrailingZeros(0), equals(64));
      expect(Platform.numberOfTrailingZeros(1), equals(0));
      expect(Platform.numberOfTrailingZeros(2), equals(1));
      expect(Platform.numberOfTrailingZeros(8), equals(3));
      expect(Platform.numberOfTrailingZeros(0x8000000000000000), equals(63));
      expect(Platform.numberOfTrailingZeros(0x100), equals(8));
    });

    test('testGetExponent', () {
      expect(Platform.getExponent(1.0), equals(0));
      expect(Platform.getExponent(2.0), equals(1));
      expect(Platform.getExponent(4.0), equals(2));
      expect(Platform.getExponent(0.5), equals(-1));
      expect(Platform.getExponent(0.25), equals(-2));
    });

    test('testScalb', () {
      expect(Platform.scalb(1.0, 0), equals(1.0));
      expect(Platform.scalb(1.0, 1), equals(2.0));
      expect(Platform.scalb(1.0, 2), equals(4.0));
      expect(Platform.scalb(1.0, -1), equals(0.5));
      expect(Platform.scalb(3.0, 2), equals(12.0));
    });

    test('testUnsignedRightShift', () {
      expect(Platform.unsignedRightShift(8, 1), equals(4));
      expect(Platform.unsignedRightShift(8, 2), equals(2));
      expect(Platform.unsignedRightShift(1, 0), equals(1));
      expect(Platform.unsignedRightShift(1, 64), equals(0));
      expect(Platform.unsignedRightShift(1, -1), equals(0));
    });

    test('testUlp', () {
      expect(Platform.ulp(0.0), equals(double.minPositive));
      expect(Platform.ulp(1.0), closeTo(Platform.dblEpsilon, 1e-30));
      expect(Platform.ulp(double.nan).isNaN, isTrue);
      expect(Platform.ulp(double.infinity), equals(double.infinity));
    });

    test('testDoubleHash', () {
      // Same values should have same hash
      expect(Platform.doubleHash(1.0), equals(Platform.doubleHash(1.0)));
      expect(Platform.doubleHash(3.14), equals(Platform.doubleHash(3.14)));

      // Different values should likely have different hash
      expect(Platform.doubleHash(1.0), isNot(equals(Platform.doubleHash(2.0))));
    });

    test('testFormatDouble', () {
      expect(Platform.formatDouble(1.0), equals('1'));
      expect(Platform.formatDouble(1.5), equals('1.5'));
      expect(Platform.formatDouble(3.14159), equals('3.14159'));
      expect(Platform.formatDouble(10.0), equals('10'));
    });

    test('testSign', () {
      // Test CCW orientation
      final a = S2Point(1, 0, 0);
      final b = S2Point(0, 1, 0);
      final c = S2Point(0, 0, 1);

      // CCW should give positive
      final ccw = Platform.sign(a, b, c);
      expect(ccw, equals(1));

      // Reversing should give negative
      final cw = Platform.sign(a, c, b);
      expect(cw, equals(-1));

      // Collinear points
      final p = S2Point(1, 0, 0);
      final q = S2Point(2, 0, 0);
      final r = S2Point(3, 0, 0);
      expect(Platform.sign(p, q, r), equals(0));
    });
  });
}

