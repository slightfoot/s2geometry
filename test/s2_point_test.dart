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

/// Tests for S2Point.
/// Ported from S2PointTest.java
library;

import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:s2geometry/s2geometry.dart';

import 'geometry_test_case.dart';

void main() {
  group('S2Point', () {
    test('testIsValid', () {
      expect(S2Point.X_POS.isValid, isTrue);
      expect(S2LatLng.fromDegrees(49.1, 112.3).toPoint().isValid, isTrue);

      // Non-normalized points are valid, although many operations require normalized points.
      expect(S2Point(3, 4, 5).isValid, isTrue);

      // Even S2Point.ZERO (0, 0, 0) is valid, although most operations won't work on it.
      expect(S2Point(0, 0, 0).isValid, isTrue);

      // But infinities and NaNs are not.
      expect(S2Point(double.infinity, 0, 0).isValid, isFalse);
      expect(S2Point(0, double.infinity, 0).isValid, isFalse);
      expect(S2Point(0, 0, double.infinity).isValid, isFalse);
      expect(S2Point(double.nan, 0, 0).isValid, isFalse);
      expect(S2Point(0, double.nan, 0).isValid, isFalse);
      expect(S2Point(0, 0, double.nan).isValid, isFalse);
    });

    test('testAddition', () {
      final a = S2Point(1, 2, 3);
      final b = S2Point(1, 1, 1);
      final aPlusB = a.add(b);
      expect(aPlusB, equals(S2Point(2, 3, 4)));
    });

    test('testSubtraction', () {
      final a = S2Point(1, 2, 3);
      final b = S2Point(1, 1, 1);
      final aMinusB = a.sub(b);
      expect(aMinusB, equals(S2Point(0, 1, 2)));
    });

    test('testScalarMultiplication', () {
      final a = S2Point(1, 2, 3);
      expect(a.mul(5.0), equals(S2Point(5, 10, 15)));
    });

    test('testScalarDivision', () {
      final a = S2Point(3, 6, 9);
      expect(a.div(3), equals(S2Point(1, 2, 3)));
    });

    test('testNegation', () {
      final a = S2Point(3, 6, 9);
      expect(a.neg(), equals(S2Point(-3, -6, -9)));
    });

    test('testComponentWiseAbs', () {
      final a = S2Point(-3, 6, -9);
      expect(a.fabs(), equals(S2Point(3, 6, 9)));
    });

    test('testVectorMethods', () {
      final a = S2Point(1, 2, 3);
      final b = S2Point(0, 1, 0);
      expect(a.add(b), equals(S2Point(1, 3, 3)));
      expect(a.sub(b), equals(S2Point(1, 1, 3)));
      expect(a.mul(2), equals(S2Point(2, 4, 6)));
      expect(a.div(2), equals(S2Point(0.5, 1, 1.5)));
      expect(a.dotProd(b), closeTo(2.0, 0));
      expect(a.crossProd(b), equals(S2Point(-3, 0, 1)));
      expect(b.normalize(), equals(b));
      expect(a.neg().fabs(), equals(a));
      expect(S2Point.X_POS.ortho(), equals(S2Point.Y_NEG));
    });

    test('testScalarTripleProduct', () {
      final a = S2Point(1, 0, 0);
      final b = S2Point(0, 1, 0);
      final c = S2Point(0, 0, 1);
      // a.dot(b.cross(c)) = (1,0,0).dot((0,1,0)x(0,0,1)) = (1,0,0).dot((1,0,0)) = 1
      expect(S2Point.scalarTripleProduct(a, b, c), closeTo(1.0, 1e-14));
      // Verify against explicit formula
      expect(a.dotProd(b.crossProd(c)), closeTo(S2Point.scalarTripleProduct(a, b, c), 1e-14));
    });

    test('testCrossProdNorm', () {
      final a = S2Point(1, 0, 0);
      final b = S2Point(0, 1, 0);
      expect(a.crossProdNorm(b), closeTo(a.crossProd(b).norm, 1e-14));

      final c = S2Point(1, 2, 3).normalize();
      final d = S2Point(4, 5, 6).normalize();
      expect(c.crossProdNorm(d), closeTo(c.crossProd(d).norm, 1e-14));
    });

    test('testFromList', () {
      final p = S2Point.fromList([1.0, 2.0, 3.0]);
      expect(p.x, equals(1.0));
      expect(p.y, equals(2.0));
      expect(p.z, equals(3.0));
    });

    test('testIndexOperator', () {
      final p = S2Point(1, 2, 3);
      expect(p[0], equals(1.0));
      expect(p[1], equals(2.0));
      expect(p[2], equals(3.0));
      expect(() => p[3], throwsRangeError);
    });

    test('testGet', () {
      final p = S2Point(1, 2, 3);
      expect(p.get(0), equals(1.0));
      expect(p.get(1), equals(2.0));
      expect(p.get(2), equals(3.0));
    });

    test('testOperators', () {
      final a = S2Point(1, 2, 3);
      final b = S2Point(4, 5, 6);

      expect(a + b, equals(S2Point(5, 7, 9)));
      expect(b - a, equals(S2Point(3, 3, 3)));
      expect(a * 2, equals(S2Point(2, 4, 6)));
      expect(a / 2, equals(S2Point(0.5, 1, 1.5)));
      expect(-a, equals(S2Point(-1, -2, -3)));
    });

    test('testNorm', () {
      final p = S2Point(3, 4, 0);
      expect(p.norm, equals(5.0));
      expect(p.norm2, equals(25.0));
    });

    test('testNormalize', () {
      final p = S2Point(3, 0, 0);
      final normalized = p.normalize();
      expect(normalized.norm, closeTo(1.0, 1e-15));
      expect(normalized, equals(S2Point.xPos));

      // Normalizing zero returns zero
      expect(S2Point.zero.normalize(), equals(S2Point.zero));
    });

    test('testLargestAbsComponent', () {
      expect(S2Point(3, 1, 2).largestAbsComponent, equals(0));
      expect(S2Point(1, 3, 2).largestAbsComponent, equals(1));
      expect(S2Point(1, 2, 3).largestAbsComponent, equals(2));
    });

    test('testAngle', () {
      final a = S2Point.xPos;
      final b = S2Point.yPos;
      expect(a.angle(b), closeTo(S2.piOver2, 1e-10));
    });

    test('testGetDistance', () {
      final a = S2Point(1, 0, 0);
      final b = S2Point(0, 1, 0);
      expect(a.getDistance(b), closeTo(math.sqrt(2), 1e-10));
      expect(a.getDistance2(b), closeTo(2.0, 1e-10));
    });

    test('testLessThan', () {
      final a = S2Point(1, 2, 3);
      final b = S2Point(1, 2, 4);
      final c = S2Point(2, 0, 0);
      expect(a.lessThan(b), isTrue);
      expect(b.lessThan(a), isFalse);
      expect(a.lessThan(c), isTrue);
    });

    test('testAequal', () {
      final a = S2Point(1, 2, 3);
      final b = S2Point(1.001, 2.001, 3.001);
      expect(a.aequal(b, 0.01), isTrue);
      expect(a.aequal(b, 0.0001), isFalse);
    });

    test('testRotate', () {
      final p = S2Point.xPos;
      final axis = S2Point.zPos;
      final rotated = p.rotate(axis, S2.piOver2);
      expect(rotated.aequal(S2Point.yPos, 1e-10), isTrue);
    });

    test('testEquality', () {
      final a = S2Point(1, 2, 3);
      final b = S2Point(1, 2, 3);
      expect(a, equals(b));

      expect(a == "not a point", isFalse);
    });

    test('testHashCode', () {
      final a = S2Point(1, 2, 3);
      final b = S2Point(1, 2, 3);
      expect(a.hashCode, equals(b.hashCode));
    });

    test('testCompareTo', () {
      final a = S2Point(1, 2, 3);
      final b = S2Point(1, 2, 4);
      expect(a.compareTo(b), lessThan(0));
      expect(b.compareTo(a), greaterThan(0));
      expect(a.compareTo(a), equals(0));
    });

    test('testToString', () {
      final p = S2Point(1, 2, 3);
      final str = p.toString();
      expect(str, contains('1'));
      expect(str, contains('2'));
      expect(str, contains('3'));
    });

    test('testToDegreesString', () {
      final p = S2LatLng.fromDegrees(45, 90).toPoint();
      final str = p.toDegreesString();
      expect(str, contains('45'));
      expect(str, contains('90'));
    });

    test('testContainsPoint', () {
      final a = S2Point(1, 2, 3);
      final b = S2Point(1, 2, 3);
      expect(a.containsPoint(b), isTrue);
      expect(a.containsPoint(S2Point(4, 5, 6)), isFalse);
    });

    test('testOrtho', () {
      // Test all three branches of ortho
      final p1 = S2Point(0, 1, 0); // largestAbsComponent = 1
      final ortho1 = p1.ortho();
      expect(ortho1.dotProd(p1), closeTo(0, 1e-10));

      final p2 = S2Point(0, 0, 1); // largestAbsComponent = 2
      final ortho2 = p2.ortho();
      expect(ortho2.dotProd(p2), closeTo(0, 1e-10));

      final p3 = S2Point(1, 0, 0); // largestAbsComponent = 0
      final ortho3 = p3.ortho();
      expect(ortho3.dotProd(p3), closeTo(0, 1e-10));
    });
  });
}
