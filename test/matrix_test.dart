// Copyright 2013 Google Inc.
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

/// Tests for Matrix.

import 'package:test/test.dart';
import 'package:s2geometry/s2geometry.dart';

void main() {
  group('Matrix', () {
    test('testCtor', () {
      // Matrix with 2 columns, 3 rows: values [1, 2, 3, 4, 5, 6]
      final m = Matrix.fromValues(2, [1, 2, 3, 4, 5, 6]);
      expect(m.cols, equals(2));
      expect(m.rows, equals(3));
      expect(m.get(0, 0), equals(1.0));
      expect(m.get(2, 1), equals(6.0));
      expect(m.get(1, 1), equals(4.0));
      m.set(1, 1, 1);
      expect(m.get(1, 1), equals(1.0));
    });

    test('testMatrixTranspose', () {
      // Matrix with 2 columns: values [1, 2, 3, 4]
      final m = Matrix.fromValues(2, [1, 2, 3, 4]);
      final expected = Matrix.fromValues(2, [1, 3, 2, 4]);
      expect(m.transpose(), equals(expected));
    });

    test('testMatrixMult', () {
      // Matrix a: 3 columns, 2 rows: [1, 2, 3, 4, 5, 6]
      final a = Matrix.fromValues(3, [1, 2, 3, 4, 5, 6]);
      // Matrix b: 1 column, 3 rows: [3, 2, 1]
      final b = Matrix.fromValues(1, [3, 2, 1]);
      // Result: 1 column, 2 rows: [10, 28]
      final result = Matrix.fromValues(1, [10, 28]);
      expect(a.mult(b), equals(result));
    });

    test('testIdentity3x3', () {
      final identity = Matrix.identity3x3();
      expect(identity.rows, equals(3));
      expect(identity.cols, equals(3));
      expect(identity.get(0, 0), equals(1.0));
      expect(identity.get(1, 1), equals(1.0));
      expect(identity.get(2, 2), equals(1.0));
      expect(identity.get(0, 1), equals(0.0));
      expect(identity.get(1, 0), equals(0.0));
    });

    test('testFromCols', () {
      final p1 = S2Point(1, 0, 0);
      final p2 = S2Point(0, 1, 0);
      final p3 = S2Point(0, 0, 1);
      final m = Matrix.fromCols([p1, p2, p3]);

      expect(m.rows, equals(3));
      expect(m.cols, equals(3));
      expect(m.getCol(0), equals(p1));
      expect(m.getCol(1), equals(p2));
      expect(m.getCol(2), equals(p3));
    });

    test('testMultPoint', () {
      final identity = Matrix.identity3x3();
      final p = S2Point(1, 2, 3);
      expect(identity.multPoint(p), equals(p));
    });

    test('testAdd', () {
      final m1 = Matrix.fromValues(2, [1, 2, 3, 4]);
      final m2 = Matrix.fromValues(2, [5, 6, 7, 8]);
      final result = Matrix.fromValues(2, [6, 8, 10, 12]);
      expect(m1.add(m2), equals(result));
    });

    test('testSub', () {
      final m1 = Matrix.fromValues(2, [5, 6, 7, 8]);
      final m2 = Matrix.fromValues(2, [1, 2, 3, 4]);
      final result = Matrix.fromValues(2, [4, 4, 4, 4]);
      expect(m1.sub(m2), equals(result));
    });

    test('testMultScalar', () {
      final m = Matrix.fromValues(2, [1, 2, 3, 4]);
      final result = Matrix.fromValues(2, [2, 4, 6, 8]);
      expect(m.multScalar(2), equals(result));
    });

    test('testFromOuter', () {
      final p1 = S2Point(1, 0, 0);
      final p2 = S2Point(0, 1, 0);
      final m = Matrix.fromOuter(p1, p2);
      
      expect(m.rows, equals(3));
      expect(m.cols, equals(3));
      // Outer product of [1,0,0] and [0,1,0] should have 1 at (0,1) and 0 elsewhere
      expect(m.get(0, 1), equals(1.0));
      expect(m.get(0, 0), equals(0.0));
      expect(m.get(1, 0), equals(0.0));
    });

    test('testEquality', () {
      final m1 = Matrix.fromValues(2, [1, 2, 3, 4]);
      final m2 = Matrix.fromValues(2, [1, 2, 3, 4]);
      final m3 = Matrix.fromValues(2, [1, 2, 3, 5]);
      
      expect(m1, equals(m2));
      expect(m1, isNot(equals(m3)));
    });

    test('testHashCode', () {
      final m1 = Matrix.fromValues(2, [1, 2, 3, 4]);
      final m2 = Matrix.fromValues(2, [1, 2, 3, 4]);

      expect(m1.hashCode, equals(m2.hashCode));
    });

    test('testHouseholder', () {
      // Householder reflection across the plane with normal (1, 0, 0)
      final normal = S2Point(1, 0, 0);
      final h = Matrix.householder(normal);

      // The Householder matrix should reflect points across the YZ plane
      // H = I - 2*n*n^T where n is unit normal
      // Reflecting (1, 0, 0) should give (-1, 0, 0)
      final p = S2Point(1, 0, 0);
      final reflected = h.multPoint(p);

      expect(reflected.x, closeTo(-1, 1e-10));
      expect(reflected.y, closeTo(0, 1e-10));
      expect(reflected.z, closeTo(0, 1e-10));
    });

    test('testHouseholderPreservesParallelToPlane', () {
      // Points in the plane should be unchanged
      final normal = S2Point(0, 0, 1);
      final h = Matrix.householder(normal);

      // Point in the XY plane
      final p = S2Point(1, 2, 0);
      final result = h.multPoint(p);

      expect(result.x, closeTo(1, 1e-10));
      expect(result.y, closeTo(2, 1e-10));
      expect(result.z, closeTo(0, 1e-10));
    });

    test('testToString', () {
      final m = Matrix.fromValues(2, [1, 2, 3, 4]);
      final str = m.toString();

      expect(str, contains('Matrix'));
      expect(str, contains('2x2'));
    });

    test('testEqualityDifferentDimensions', () {
      final m1 = Matrix.fromValues(2, [1, 2, 3, 4]);
      final m2 = Matrix.fromValues(1, [1, 2, 3, 4]);

      expect(m1 == m2, isFalse);
    });

    test('testEqualityDifferentType', () {
      final m = Matrix.fromValues(2, [1, 2, 3, 4]);

      expect(m == S2Point(1, 2, 3), isFalse);
    });

    test('testConstructorWithNegativeRows', () {
      expect(() => Matrix(-1, 2), throwsArgumentError);
    });

    test('testConstructorWithNegativeCols', () {
      expect(() => Matrix(2, -1), throwsArgumentError);
    });

    test('testFromValuesNegativeCols', () {
      expect(() => Matrix.fromValues(-1, [1, 2, 3]), throwsArgumentError);
    });

    test('testFromValuesNotEvenMultiple', () {
      expect(() => Matrix.fromValues(3, [1, 2, 3, 4]), throwsArgumentError);
    });

    test('testZeroMatrix', () {
      final m = Matrix(2, 2);

      expect(m.get(0, 0), equals(0.0));
      expect(m.get(0, 1), equals(0.0));
      expect(m.get(1, 0), equals(0.0));
      expect(m.get(1, 1), equals(0.0));
    });
  });
}

