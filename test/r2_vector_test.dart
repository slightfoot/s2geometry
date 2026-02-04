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

/// Tests for R2Vector.
/// Ported from R2VectorTest.java
library;

import 'package:test/test.dart';
import 'package:s2geometry/s2geometry.dart';

import 'geometry_test_case.dart';

void main() {
  group('R2Vector', () {
    test('testConstructors', () {
      final coordinates = <double>[1.5, 2.5];
      final v = R2Vector.fromArray(coordinates);
      expect(v, equals(R2Vector(1.5, 2.5)));
      assertExactly(1.5, v.x);
      assertExactly(2.5, v.y);
    });

    test('testOrtho', () {
      expect(R2Vector(1, 1), equals(R2Vector(1, -1).ortho()));
      expect(R2Vector(1, -1), equals(R2Vector(-1, -1).ortho()));
      expect(R2Vector(-1, -1), equals(R2Vector(-1, 1).ortho()));
      expect(R2Vector(1, 1), equals(R2Vector(1, -1).ortho()));
    });

    test('testAdd', () {
      expect(R2Vector(5, 5), equals(R2Vector.addStatic(R2Vector(4, 3), R2Vector(1, 2))));
      expect(R2Vector(5, 5), equals(R2Vector(4, 3).add(R2Vector(1, 2))));
    });

    test('testSub', () {
      expect(R2Vector(3, 1), equals(R2Vector.subStatic(R2Vector(4, 3), R2Vector(1, 2))));
      expect(R2Vector(3, 1), equals(R2Vector(4, 3).sub(R2Vector(1, 2))));
    });

    test('testMul', () {
      assertAlmostEquals(12.0, R2Vector.mulStatic(R2Vector(4, 3), 3.0).x);
      assertAlmostEquals(9.0, R2Vector.mulStatic(R2Vector(4, 3), 3.0).y);
      assertAlmostEquals(12.0, R2Vector(4, 3).mul(3.0).x);
      assertAlmostEquals(9.0, R2Vector(4, 3).mul(3.0).y);
    });

    test('testOriginConstructor', () {
      final v = R2Vector.origin();
      expect(v.x, equals(0.0));
      expect(v.y, equals(0.0));
    });

    test('testFromListConstructor', () {
      final v = R2Vector.fromList([3.0, 4.0]);
      expect(v.x, equals(3.0));
      expect(v.y, equals(4.0));
    });

    test('testFromArrayThrowsOnWrongSize', () {
      // Too few elements - throws RangeError at initializer (coords[1])
      expect(() => R2Vector.fromArray([1.0]), throwsRangeError);
      // Too many elements - throws ArgumentError in body (line 37)
      expect(() => R2Vector.fromArray([1.0, 2.0, 3.0]), throwsArgumentError);
      // fromList too many elements - throws ArgumentError in body (line 46)
      expect(() => R2Vector.fromList([1.0, 2.0, 3.0]), throwsArgumentError);
    });

    test('testGetXGetY', () {
      final v = R2Vector(5.0, 6.0);
      expect(v.getX(), equals(5.0));
      expect(v.getY(), equals(6.0));
    });

    test('testIndexOperator', () {
      final v = R2Vector(2.0, 3.0);
      expect(v[0], equals(2.0));
      expect(v[1], equals(3.0));
      expect(() => v[2], throwsRangeError);
    });

    test('testIndexAssignOperator', () {
      final v = R2Vector(0, 0);
      v[0] = 5.0;
      v[1] = 7.0;
      expect(v.x, equals(5.0));
      expect(v.y, equals(7.0));
      expect(() => v[2] = 9.0, throwsRangeError);
    });

    test('testSetFrom', () {
      final v1 = R2Vector(1.0, 2.0);
      final v2 = R2Vector(0, 0);
      v2.setFrom(v1);
      expect(v2.x, equals(1.0));
      expect(v2.y, equals(2.0));
    });

    test('testSet', () {
      final v = R2Vector(0, 0);
      v.set(3.0, 4.0);
      expect(v.x, equals(3.0));
      expect(v.y, equals(4.0));
    });

    test('testOperatorPlus', () {
      final v1 = R2Vector(1, 2);
      final v2 = R2Vector(3, 4);
      final result = v1 + v2;
      expect(result.x, equals(4.0));
      expect(result.y, equals(6.0));
    });

    test('testOperatorMinus', () {
      final v1 = R2Vector(5, 7);
      final v2 = R2Vector(2, 3);
      final result = v1 - v2;
      expect(result.x, equals(3.0));
      expect(result.y, equals(4.0));
    });

    test('testOperatorMultiply', () {
      final v = R2Vector(2, 3);
      final result = v * 4;
      expect(result.x, equals(8.0));
      expect(result.y, equals(12.0));
    });

    test('testOperatorDivide', () {
      final v = R2Vector(8, 12);
      final result = v / 4;
      expect(result.x, equals(2.0));
      expect(result.y, equals(3.0));
    });

    test('testOperatorNegate', () {
      final v = R2Vector(3, -4);
      final result = -v;
      expect(result.x, equals(-3.0));
      expect(result.y, equals(4.0));
    });

    test('testNorm', () {
      final v = R2Vector(3, 4);
      expect(v.norm, closeTo(5.0, 1e-10));
    });

    test('testNorm2', () {
      final v = R2Vector(3, 4);
      expect(v.norm2, equals(25.0));
    });

    test('testNormalize', () {
      final v = R2Vector(3, 4).normalize();
      expect(v.norm, closeTo(1.0, 1e-10));
      expect(v.x, closeTo(0.6, 1e-10));
      expect(v.y, closeTo(0.8, 1e-10));
    });

    test('testNormalizeZeroVector', () {
      final v = R2Vector(0, 0).normalize();
      expect(v.x, equals(0.0));
      expect(v.y, equals(0.0));
    });

    test('testDotProd', () {
      final v1 = R2Vector(2, 3);
      final v2 = R2Vector(4, 5);
      expect(v1.dotProd(v2), equals(23.0)); // 2*4 + 3*5 = 23
    });

    test('testCrossProd', () {
      final v1 = R2Vector(2, 3);
      final v2 = R2Vector(4, 5);
      expect(v1.crossProd(v2), equals(-2.0)); // 2*5 - 3*4 = -2
    });

    test('testLessThan', () {
      expect(R2Vector(1, 2).lessThan(R2Vector(2, 1)), isTrue);
      expect(R2Vector(2, 1).lessThan(R2Vector(1, 2)), isFalse);
      expect(R2Vector(1, 1).lessThan(R2Vector(1, 2)), isTrue);
      expect(R2Vector(1, 2).lessThan(R2Vector(1, 1)), isFalse);
    });

    test('testEquality', () {
      expect(R2Vector(1, 2), equals(R2Vector(1, 2)));
      expect(R2Vector(1, 2), isNot(equals(R2Vector(1, 3))));
      expect(R2Vector(1, 2), isNot(equals("not a vector")));
    });

    test('testHashCode', () {
      final v1 = R2Vector(1, 2);
      final v2 = R2Vector(1, 2);
      expect(v1.hashCode, equals(v2.hashCode));
    });

    test('testToString', () {
      final v = R2Vector(1.5, 2.5);
      final str = v.toString();
      expect(str, contains('1.5'));
      expect(str, contains('2.5'));
    });
  });
}
