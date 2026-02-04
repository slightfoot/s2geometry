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
  // Test helper methods for testing the traversal order.
  int swapAxes(int ij) {
    return ((ij >> 1) & 1) + ((ij & 1) << 1);
  }

  int invertBits(int ij) {
    return ij ^ 3;
  }

  group('S2', () {
    test('testMachineEpsilon', () {
      // Verifies that the machine epsilon is exactly the same as the value in S2.dblEpsilon.
      double machEps = 1.0;
      do {
        machEps /= 2.0;
      } while ((1.0 + (machEps / 2.0)) != 1.0);

      expect(S2.dblEpsilon, equals(machEps));
    });

    test('testTraversalOrder', () {
      for (int r = 0; r < 4; ++r) {
        for (int i = 0; i < 4; ++i) {
          // Check consistency with respect to swapping axes.
          expect(S2.ijToPos(r, i), equals(S2.ijToPos(r ^ S2.swapMask, swapAxes(i))));
          expect(S2.posToIJ(r, i), equals(swapAxes(S2.posToIJ(r ^ S2.swapMask, i))));

          // Check consistency with respect to reversing axis directions.
          expect(S2.ijToPos(r, i), equals(S2.ijToPos(r ^ S2.invertMask, invertBits(i))));
          expect(S2.posToIJ(r, i), equals(invertBits(S2.posToIJ(r ^ S2.invertMask, i))));

          // Check that the two tables are inverses of each other.
          expect(S2.ijToPos(r, S2.posToIJ(r, i)), equals(i));
          expect(S2.posToIJ(r, S2.ijToPos(r, i)), equals(i));
        }
      }
    });

    test('testPosToOrientation', () {
      // Test that posToOrientation returns expected values.
      expect(S2.posToOrientation(0), equals(S2.swapMask));
      expect(S2.posToOrientation(1), equals(0));
      expect(S2.posToOrientation(2), equals(0));
      expect(S2.posToOrientation(3), equals(S2.invertMask + S2.swapMask));
    });

    test('testIsUnitLength', () {
      // Test points that are unit length.
      expect(S2.isUnitLength(S2Point(1, 0, 0)), isTrue);
      expect(S2.isUnitLength(S2Point(0, 1, 0)), isTrue);
      expect(S2.isUnitLength(S2Point(0, 0, 1)), isTrue);
      expect(S2.isUnitLength(S2Point(1, 1, 1).normalize()), isTrue);

      // Test points that are not unit length.
      expect(S2.isUnitLength(S2Point(0, 0, 0)), isFalse);
      expect(S2.isUnitLength(S2Point(1, 1, 1)), isFalse);
      expect(S2.isUnitLength(S2Point(2, 0, 0)), isFalse);
    });

    test('testOrigin', () {
      // The origin should be approximately unit length.
      expect(S2.isUnitLength(S2.origin), isTrue);
    });

    test('testOrtho', () {
      // Test that ortho returns a unit vector orthogonal to the input.
      final p = S2Point(1, 2, 3).normalize();
      final orth = S2.ortho(p);

      // Should be unit length.
      expect(S2.isUnitLength(orth), isTrue);

      // Should be orthogonal to p.
      expect(p.dotProd(orth).abs(), lessThan(1e-14));
    });

    test('testApproxEquals', () {
      final p1 = S2Point(1, 0, 0);
      final p2 = S2Point(1, 1e-16, 0).normalize();

      // Very close points should be approximately equal.
      expect(S2.approxEquals(p1, p2), isTrue);

      // Same point should be approximately equal.
      expect(S2.approxEquals(p1, p1), isTrue);

      // Distant points should not be approximately equal.
      final p3 = S2Point(0, 1, 0);
      expect(S2.approxEquals(p1, p3), isFalse);
    });

    test('testApproxEqualsDouble', () {
      expect(S2.approxEqualsDouble(1.0, 1.0 + 1e-16), isTrue);
      expect(S2.approxEqualsDouble(1.0, 1.0), isTrue);
      expect(S2.approxEqualsDouble(1.0, 2.0), isFalse);
    });

    test('testAngleArea', () {
      final pz = S2Point(0, 0, 1);
      final p000 = S2Point(1, 0, 0);
      final p045 = S2Point(1, 1, 0).normalize();
      final p090 = S2Point(0, 1, 0);

      // Test area calculation for a right spherical triangle.
      // A triangle with vertices at (1,0,0), (0,1,0), (0,0,1) has area = pi/2.
      final areaValue = S2.area(p000, p090, pz);
      expect(areaValue, closeTo(S2.piOver2, 1e-14));

      // Make sure that area() has good *relative* accuracy even for very small areas.
      final eps = 1e-10;
      final pepsx = S2Point(eps, 0, 1).normalize();
      final pepsy = S2Point(0, eps, 1).normalize();
      final expected1 = 0.5 * eps * eps;
      expect(S2.area(pepsx, pepsy, pz), closeTo(expected1, 1e-14 * expected1));

      // Make sure that it can handle degenerate triangles.
      final pr = S2Point(0.257, -0.5723, 0.112).normalize();
      final pq = S2Point(-0.747, 0.401, 0.2235).normalize();
      expect(S2.area(pr, pr, pr), equals(0.0));
      expect(S2.area(pr, pq, pr), closeTo(0.0, 1e-14));
      expect(S2.area(p000, p045, p090), equals(0.0));
    });

    test('testGirardArea', () {
      final pz = S2Point(0, 0, 1);
      final p000 = S2Point(1, 0, 0);
      final p090 = S2Point(0, 1, 0);

      // A triangle with vertices at (1,0,0), (0,1,0), (0,0,1) has area = pi/2.
      final areaValue = S2.girardArea(p000, p090, pz);
      expect(areaValue, closeTo(S2.piOver2, 1e-10));
    });

    test('testSignedArea', () {
      final pz = S2Point(0, 0, 1);
      final p000 = S2Point(1, 0, 0);
      final p090 = S2Point(0, 1, 0);

      // CCW triangle should have positive signed area.
      final signedAreaValue = S2.signedArea(p000, p090, pz);
      expect(signedAreaValue, greaterThan(0));

      // CW triangle should have negative signed area.
      final signedAreaReverse = S2.signedArea(p000, pz, p090);
      expect(signedAreaReverse, lessThan(0));

      // The magnitudes should be equal.
      expect(signedAreaValue.abs(), closeTo(signedAreaReverse.abs(), 1e-14));
    });

    test('testConstants', () {
      expect(S2.pi, equals(math.pi));
      expect(S2.piOver2, equals(math.pi / 2));
      expect(S2.piOver4, equals(math.pi / 4));
      expect(S2.oneOverPi, closeTo(1 / math.pi, 1e-15));
      expect(S2.sqrt2, closeTo(math.sqrt(2), 1e-15));
      expect(S2.sqrt3, closeTo(math.sqrt(3), 1e-15));
      expect(S2.sqrt1Over2, closeTo(1 / math.sqrt(2), 1e-15));
    });
  });
}

