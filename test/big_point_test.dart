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

import 'package:s2geometry/s2geometry.dart';
import 'package:test/test.dart';

void main() {
  group('BigPoint', () {
    test('testConstructor', () {
      final p = BigPoint(1.0, 2.0, 3.0);
      expect(p.x, equals(1.0));
      expect(p.y, equals(2.0));
      expect(p.z, equals(3.0));
    });

    test('testFromS2Point', () {
      final s2p = S2Point(1.0, 2.0, 3.0);
      final bp = BigPoint.fromS2Point(s2p);
      expect(bp.x, equals(1.0));
      expect(bp.y, equals(2.0));
      expect(bp.z, equals(3.0));
    });

    test('testToS2Point', () {
      final bp = BigPoint(1.0, 2.0, 3.0);
      final s2p = bp.toS2Point();
      expect(s2p.x, equals(1.0));
      expect(s2p.y, equals(2.0));
      expect(s2p.z, equals(3.0));
    });

    test('testCrossProd', () {
      // Cross product of x and y axes should give z axis
      final x = BigPoint(1.0, 0.0, 0.0);
      final y = BigPoint(0.0, 1.0, 0.0);
      final z = x.crossProd(y);
      expect(z.x, equals(0.0));
      expect(z.y, equals(0.0));
      expect(z.z, equals(1.0));

      // Cross product of y and x axes should give -z axis
      final negZ = y.crossProd(x);
      expect(negZ.x, equals(0.0));
      expect(negZ.y, equals(0.0));
      expect(negZ.z, equals(-1.0));

      // Cross product of a vector with itself should be zero
      final a = BigPoint(1.0, 2.0, 3.0);
      final zero = a.crossProd(a);
      expect(zero.x, equals(0.0));
      expect(zero.y, equals(0.0));
      expect(zero.z, equals(0.0));
    });

    test('testDotProd', () {
      // Orthogonal vectors have dot product = 0
      final x = BigPoint(1.0, 0.0, 0.0);
      final y = BigPoint(0.0, 1.0, 0.0);
      expect(x.dotProd(y), equals(0.0));

      // Same vector has dot product = norm^2
      final a = BigPoint(1.0, 2.0, 3.0);
      expect(a.dotProd(a), equals(14.0)); // 1 + 4 + 9

      // General case
      final b = BigPoint(4.0, 5.0, 6.0);
      expect(a.dotProd(b), equals(32.0)); // 4 + 10 + 18
    });

    test('testNorm', () {
      final a = BigPoint(3.0, 4.0, 0.0);
      expect(a.norm2(), equals(25.0));
      expect(a.norm(), equals(5.0));

      final unit = BigPoint(1.0, 0.0, 0.0);
      expect(unit.norm(), equals(1.0));
    });

    test('testSignum', () {
      final pos = BigPoint(1.0, 2.0, 3.0);
      expect(pos.xSignum, equals(1));
      expect(pos.ySignum, equals(1));
      expect(pos.zSignum, equals(1));

      final neg = BigPoint(-1.0, -2.0, -3.0);
      expect(neg.xSignum, equals(-1));
      expect(neg.ySignum, equals(-1));
      expect(neg.zSignum, equals(-1));

      final zero = BigPoint(0.0, 0.0, 0.0);
      expect(zero.xSignum, equals(0));
      expect(zero.ySignum, equals(0));
      expect(zero.zSignum, equals(0));
    });

    test('testIsAntipodal', () {
      final a = BigPoint(1.0, 2.0, 3.0);
      final negA = BigPoint(-1.0, -2.0, -3.0);
      expect(a.isAntipodal(negA), isTrue);
      expect(negA.isAntipodal(a), isTrue);

      final b = BigPoint(1.0, 2.0, 3.0);
      expect(a.isAntipodal(b), isFalse);
    });

    test('testMultiply', () {
      final a = BigPoint(1.0, 2.0, 3.0);
      final scaled = a.multiply(2.0);
      expect(scaled.x, equals(2.0));
      expect(scaled.y, equals(4.0));
      expect(scaled.z, equals(6.0));

      final zero = a.multiply(0.0);
      expect(zero.x, equals(0.0));
      expect(zero.y, equals(0.0));
      expect(zero.z, equals(0.0));
    });

    test('testSubtract', () {
      final a = BigPoint(4.0, 5.0, 6.0);
      final b = BigPoint(1.0, 2.0, 3.0);
      final diff = a.subtract(b);
      expect(diff.x, equals(3.0));
      expect(diff.y, equals(3.0));
      expect(diff.z, equals(3.0));
    });

    test('testCompareTo', () {
      final a = BigPoint(1.0, 2.0, 3.0);
      final b = BigPoint(2.0, 2.0, 3.0);
      final c = BigPoint(1.0, 3.0, 3.0);
      final d = BigPoint(1.0, 2.0, 4.0);
      final same = BigPoint(1.0, 2.0, 3.0);

      expect(a.compareTo(b), lessThan(0));
      expect(b.compareTo(a), greaterThan(0));
      expect(a.compareTo(c), lessThan(0));
      expect(a.compareTo(d), lessThan(0));
      expect(a.compareTo(same), equals(0));
    });

    test('testEquals', () {
      final a = BigPoint(1.0, 2.0, 3.0);
      final b = BigPoint(1.0, 2.0, 3.0);
      final c = BigPoint(1.0, 2.0, 4.0);

      expect(a == b, isTrue);
      expect(a == c, isFalse);
      expect(a.hashCode, equals(b.hashCode));
    });

    test('testToString', () {
      final a = BigPoint(1.0, 2.0, 3.0);
      expect(a.toString(), equals('BigPoint(1.0, 2.0, 3.0)'));
    });
  });
}

