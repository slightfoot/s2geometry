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

/// Tests for S1Interval.
/// Ported from S1IntervalTest.java
library;

import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:s2geometry/s2geometry.dart';

import 'geometry_test_case.dart';

// Constants for convenience
final double pi = math.pi;
final double mPi2 = S2.mPi2;

void main() {
  // Create standard intervals for testing
  final empty = S1Interval.empty();
  final full = S1Interval.full();
  // Single-point intervals:
  final zero = S1Interval(0, 0);
  final pi2 = S1Interval(mPi2, mPi2);
  final piInterval = S1Interval(pi, pi);
  final mipi = S1Interval(-pi, -pi); // Same as "pi" after normalization.
  final mipi2 = S1Interval(-mPi2, -mPi2);
  // Single quadrants:
  final quad1 = S1Interval(0, mPi2);
  final quad2 = S1Interval(mPi2, -pi);
  final quad3 = S1Interval(pi, -mPi2);
  final quad4 = S1Interval(-mPi2, 0);
  // Quadrant pairs:
  final quad12 = S1Interval(0, -pi);
  final quad23 = S1Interval(mPi2, -mPi2);
  final quad34 = S1Interval(-pi, 0);
  // Quadrant triples:
  final quad123 = S1Interval(0, -mPi2);
  final quad234 = S1Interval(mPi2, 0);
  final quad341 = S1Interval(pi, mPi2);
  final quad412 = S1Interval(-mPi2, -pi);
  // Small intervals around the midpoints between quadrants
  final mid12 = S1Interval(mPi2 - 0.01, mPi2 + 0.02);
  final mid23 = S1Interval(pi - 0.01, -pi + 0.02);
  final mid34 = S1Interval(-mPi2 - 0.01, -mPi2 + 0.02);
  final mid41 = S1Interval(-0.01, 0.02);

  group('S1Interval', () {
    test('testConstructorsAndAccessors', () {
      // Spot-check the constructors and accessors.
      assertExactly(0, quad12.lo);
      assertExactly(pi, quad12.hi);
      assertExactly(pi, quad34.get(0));
      assertExactly(0, quad34.get(1));
      assertExactly(pi, piInterval.lo);
      assertExactly(pi, piInterval.hi);

      // Check that [-Pi, -Pi] is normalized to [Pi, Pi].
      assertExactly(pi, mipi.lo);
      assertExactly(pi, mipi.hi);
      assertExactly(mPi2, quad23.lo);
      assertExactly(-mPi2, quad23.hi);

      // Check that the default S1Interval is identical to Empty().
      final defaultEmpty = S1Interval.init();
      expect(defaultEmpty.isValid, isTrue);
      expect(defaultEmpty.isEmpty, isTrue);
      assertExactly(empty.lo, defaultEmpty.lo);
      assertExactly(empty.hi, defaultEmpty.hi);
    });

    test('testSimplePredicates', () {
      // is_valid(), is_empty(), is_full(), is_inverted()
      expect(zero.isValid && !zero.isEmpty && !zero.isFull, isTrue);
      expect(empty.isValid && empty.isEmpty && !empty.isFull, isTrue);
      expect(empty.isInverted, isTrue);
      expect(full.isValid && !full.isEmpty && full.isFull, isTrue);
      expect(!quad12.isEmpty && !quad12.isFull && !quad12.isInverted, isTrue);
      expect(!quad23.isEmpty && !quad23.isFull && quad23.isInverted, isTrue);
      expect(piInterval.isValid && !piInterval.isEmpty && !piInterval.isInverted, isTrue);
      expect(mipi.isValid && !mipi.isEmpty && !mipi.isInverted, isTrue);
    });

    test('testGetCenter', () {
      assertExactly(mPi2, quad12.getCenter());
      assertExactly(3.0 - pi, S1Interval(3.1, 2.9).getCenter());
      assertExactly(pi - 3.0, S1Interval(-2.9, -3.1).getCenter());
      assertExactly(pi, S1Interval(2.1, -2.1).getCenter());
      assertExactly(pi, piInterval.getCenter());
      assertExactly(pi, mipi.getCenter());
      assertExactly(pi, quad23.getCenter().abs());
      assertExactly(0.75 * pi, quad123.getCenter());
    });

    test('testGetLength', () {
      assertExactly(pi, quad12.getLength());
      assertExactly(0, piInterval.getLength());
      assertExactly(0, mipi.getLength());
      assertExactly(1.5 * pi, quad123.getLength());
      assertExactly(pi, quad23.getLength().abs());
      assertExactly(2 * pi, full.getLength());
      expect(empty.getLength() < 0, isTrue);
    });

    test('testComplement', () {
      expect(empty.complement().isFull, isTrue);
      expect(full.complement().isEmpty, isTrue);
      expect(piInterval.complement().isFull, isTrue);
      expect(mipi.complement().isFull, isTrue);
      expect(zero.complement().isFull, isTrue);
      expect(quad12.complement().approxEquals(quad34), isTrue);
      expect(quad34.complement().approxEquals(quad12), isTrue);
      expect(quad123.complement().approxEquals(quad4), isTrue);
    });

    test('testContains', () {
      // Contains(double), InteriorContains(double)
      expect(
          !empty.containsPoint(0) && !empty.containsPoint(pi) && !empty.containsPoint(-pi), isTrue);
      expect(!empty.interiorContainsPoint(pi) && !empty.interiorContainsPoint(-pi), isTrue);
      expect(full.containsPoint(0) && full.containsPoint(pi) && full.containsPoint(-pi), isTrue);
      expect(full.interiorContainsPoint(pi) && full.interiorContainsPoint(-pi), isTrue);
      expect(
          quad12.containsPoint(0) && quad12.containsPoint(pi) && quad12.containsPoint(-pi), isTrue);
      expect(quad12.interiorContainsPoint(mPi2) && !quad12.interiorContainsPoint(0), isTrue);
      expect(!quad12.interiorContainsPoint(pi) && !quad12.interiorContainsPoint(-pi), isTrue);
      expect(quad23.containsPoint(mPi2) && quad23.containsPoint(-mPi2), isTrue);
      expect(quad23.containsPoint(pi) && quad23.containsPoint(-pi), isTrue);
      expect(!quad23.containsPoint(0), isTrue);
      expect(!quad23.interiorContainsPoint(mPi2) && !quad23.interiorContainsPoint(-mPi2), isTrue);
      expect(quad23.interiorContainsPoint(pi) && quad23.interiorContainsPoint(-pi), isTrue);
      expect(!quad23.interiorContainsPoint(0), isTrue);
      expect(
          piInterval.containsPoint(pi) &&
              piInterval.containsPoint(-pi) &&
              !piInterval.containsPoint(0),
          isTrue);
      expect(
          !piInterval.interiorContainsPoint(pi) && !piInterval.interiorContainsPoint(-pi), isTrue);
      expect(mipi.containsPoint(pi) && mipi.containsPoint(-pi) && !mipi.containsPoint(0), isTrue);
      expect(!mipi.interiorContainsPoint(pi) && !mipi.interiorContainsPoint(-pi), isTrue);
      expect(zero.containsPoint(0) && !zero.interiorContainsPoint(0), isTrue);
    });

    // Helper function for testIntervalOps
    void testIntervalOpsHelper(S1Interval x, S1Interval y, String expectedRelation,
        S1Interval expectedUnion, S1Interval expectedIntersection) {
      expect(x.contains(y), equals(expectedRelation[0] == 'T'));
      expect(x.interiorContains(y), equals(expectedRelation[1] == 'T'));
      expect(x.intersects(y), equals(expectedRelation[2] == 'T'));
      expect(x.interiorIntersects(y), equals(expectedRelation[3] == 'T'));

      expect(x.union(y), equals(expectedUnion));
      expect(x.intersection(y), equals(expectedIntersection));

      expect(x.contains(y), equals(x.union(y) == x));
      expect(x.intersects(y), equals(!x.intersection(y).isEmpty));

      if (y.lo == y.hi) {
        var r = S1Interval.copy(x);
        r = r.addPoint(y.lo);
        expect(r, equals(expectedUnion));
      }
    }

    test('testIntervalOps', () {
      // Contains(S1Interval), InteriorContains(S1Interval), Intersects(),
      // InteriorIntersects(), Union(), Intersection()
      testIntervalOpsHelper(empty, empty, "TTFF", empty, empty);
      testIntervalOpsHelper(empty, full, "FFFF", full, empty);
      testIntervalOpsHelper(empty, zero, "FFFF", zero, empty);
      testIntervalOpsHelper(empty, piInterval, "FFFF", piInterval, empty);
      testIntervalOpsHelper(empty, mipi, "FFFF", mipi, empty);

      testIntervalOpsHelper(full, empty, "TTFF", full, empty);
      testIntervalOpsHelper(full, full, "TTTT", full, full);
      testIntervalOpsHelper(full, zero, "TTTT", full, zero);
      testIntervalOpsHelper(full, piInterval, "TTTT", full, piInterval);
      testIntervalOpsHelper(full, mipi, "TTTT", full, mipi);
      testIntervalOpsHelper(full, quad12, "TTTT", full, quad12);
      testIntervalOpsHelper(full, quad23, "TTTT", full, quad23);

      testIntervalOpsHelper(zero, empty, "TTFF", zero, empty);
      testIntervalOpsHelper(zero, full, "FFTF", full, zero);
      testIntervalOpsHelper(zero, zero, "TFTF", zero, zero);
      testIntervalOpsHelper(zero, piInterval, "FFFF", S1Interval(0, pi), empty);
      testIntervalOpsHelper(zero, pi2, "FFFF", quad1, empty);
      testIntervalOpsHelper(zero, mipi, "FFFF", quad12, empty);
      testIntervalOpsHelper(zero, mipi2, "FFFF", quad4, empty);
      testIntervalOpsHelper(zero, quad12, "FFTF", quad12, zero);
      testIntervalOpsHelper(zero, quad23, "FFFF", quad123, empty);

      testIntervalOpsHelper(pi2, empty, "TTFF", pi2, empty);
      testIntervalOpsHelper(pi2, full, "FFTF", full, pi2);
      testIntervalOpsHelper(pi2, zero, "FFFF", quad1, empty);
      testIntervalOpsHelper(pi2, piInterval, "FFFF", S1Interval(mPi2, pi), empty);
      testIntervalOpsHelper(pi2, pi2, "TFTF", pi2, pi2);
      testIntervalOpsHelper(pi2, mipi, "FFFF", quad2, empty);
      testIntervalOpsHelper(pi2, mipi2, "FFFF", quad23, empty);
      testIntervalOpsHelper(pi2, quad12, "FFTF", quad12, pi2);
      testIntervalOpsHelper(pi2, quad23, "FFTF", quad23, pi2);

      testIntervalOpsHelper(piInterval, empty, "TTFF", piInterval, empty);
      testIntervalOpsHelper(piInterval, full, "FFTF", full, piInterval);
      testIntervalOpsHelper(piInterval, zero, "FFFF", S1Interval(pi, 0), empty);
      testIntervalOpsHelper(piInterval, piInterval, "TFTF", piInterval, piInterval);
      testIntervalOpsHelper(piInterval, pi2, "FFFF", S1Interval(mPi2, pi), empty);
      testIntervalOpsHelper(piInterval, mipi, "TFTF", piInterval, piInterval);
      testIntervalOpsHelper(piInterval, mipi2, "FFFF", quad3, empty);
      testIntervalOpsHelper(piInterval, quad12, "FFTF", S1Interval(0, pi), piInterval);
      testIntervalOpsHelper(piInterval, quad23, "FFTF", quad23, piInterval);

      testIntervalOpsHelper(mipi, empty, "TTFF", mipi, empty);
      testIntervalOpsHelper(mipi, full, "FFTF", full, mipi);
      testIntervalOpsHelper(mipi, zero, "FFFF", quad34, empty);
      testIntervalOpsHelper(mipi, piInterval, "TFTF", mipi, mipi);
      testIntervalOpsHelper(mipi, pi2, "FFFF", quad2, empty);
      testIntervalOpsHelper(mipi, mipi, "TFTF", mipi, mipi);
      testIntervalOpsHelper(mipi, mipi2, "FFFF", S1Interval(-pi, -mPi2), empty);
      testIntervalOpsHelper(mipi, quad12, "FFTF", quad12, mipi);
      testIntervalOpsHelper(mipi, quad23, "FFTF", quad23, mipi);

      testIntervalOpsHelper(quad12, empty, "TTFF", quad12, empty);
      testIntervalOpsHelper(quad12, full, "FFTT", full, quad12);
      testIntervalOpsHelper(quad12, zero, "TFTF", quad12, zero);
      testIntervalOpsHelper(quad12, piInterval, "TFTF", quad12, piInterval);
      testIntervalOpsHelper(quad12, mipi, "TFTF", quad12, mipi);
      testIntervalOpsHelper(quad12, quad12, "TFTT", quad12, quad12);
      testIntervalOpsHelper(quad12, quad23, "FFTT", quad123, quad2);
      testIntervalOpsHelper(quad12, quad34, "FFTF", full, quad12);

      testIntervalOpsHelper(quad23, empty, "TTFF", quad23, empty);
      testIntervalOpsHelper(quad23, full, "FFTT", full, quad23);
      testIntervalOpsHelper(quad23, zero, "FFFF", quad234, empty);
      testIntervalOpsHelper(quad23, piInterval, "TTTT", quad23, piInterval);
      testIntervalOpsHelper(quad23, mipi, "TTTT", quad23, mipi);
      testIntervalOpsHelper(quad23, quad12, "FFTT", quad123, quad2);
      testIntervalOpsHelper(quad23, quad23, "TFTT", quad23, quad23);
      testIntervalOpsHelper(quad23, quad34, "FFTT", quad234, S1Interval(-pi, -mPi2));

      testIntervalOpsHelper(quad1, quad23, "FFTF", quad123, S1Interval(mPi2, mPi2));
      testIntervalOpsHelper(quad2, quad3, "FFTF", quad23, mipi);
      testIntervalOpsHelper(quad3, quad2, "FFTF", quad23, piInterval);
      testIntervalOpsHelper(quad2, piInterval, "TFTF", quad2, piInterval);
      testIntervalOpsHelper(quad2, mipi, "TFTF", quad2, mipi);
      testIntervalOpsHelper(quad3, piInterval, "TFTF", quad3, piInterval);
      testIntervalOpsHelper(quad3, mipi, "TFTF", quad3, mipi);

      testIntervalOpsHelper(quad12, mid12, "TTTT", quad12, mid12);
      testIntervalOpsHelper(mid12, quad12, "FFTT", quad12, mid12);

      final quad12eps = S1Interval(quad12.lo, mid23.hi);
      final quad2hi = S1Interval(mid23.lo, quad12.hi);
      testIntervalOpsHelper(quad12, mid23, "FFTT", quad12eps, quad2hi);
      testIntervalOpsHelper(mid23, quad12, "FFTT", quad12eps, quad2hi);

      final quad412eps = S1Interval(mid34.lo, quad12.hi);
      testIntervalOpsHelper(quad12, mid34, "FFFF", quad412eps, empty);
      testIntervalOpsHelper(mid34, quad12, "FFFF", quad412eps, empty);

      final quadeps12 = S1Interval(mid41.lo, quad12.hi);
      final quad1lo = S1Interval(quad12.lo, mid41.hi);
      testIntervalOpsHelper(quad12, mid41, "FFTT", quadeps12, quad1lo);
      testIntervalOpsHelper(mid41, quad12, "FFTT", quadeps12, quad1lo);

      final quad2lo = S1Interval(quad23.lo, mid12.hi);
      final quad3hi = S1Interval(mid34.lo, quad23.hi);
      final quadeps23 = S1Interval(mid12.lo, quad23.hi);
      final quad23eps = S1Interval(quad23.lo, mid34.hi);
      final quadeps123 = S1Interval(mid41.lo, quad23.hi);
      testIntervalOpsHelper(quad23, mid12, "FFTT", quadeps23, quad2lo);
      testIntervalOpsHelper(mid12, quad23, "FFTT", quadeps23, quad2lo);
      testIntervalOpsHelper(quad23, mid23, "TTTT", quad23, mid23);
      testIntervalOpsHelper(mid23, quad23, "FFTT", quad23, mid23);
      testIntervalOpsHelper(quad23, mid34, "FFTT", quad23eps, quad3hi);
      testIntervalOpsHelper(mid34, quad23, "FFTT", quad23eps, quad3hi);
      testIntervalOpsHelper(quad23, mid41, "FFFF", quadeps123, empty);
      testIntervalOpsHelper(mid41, quad23, "FFFF", quadeps123, empty);
    });

    test('testAddPoint', () {
      var r = S1Interval.empty();
      r = r.addPoint(0);
      expect(r, equals(zero));
      r = S1Interval.empty();
      r = r.addPoint(pi);
      expect(r, equals(piInterval));
      r = S1Interval.empty();
      r = r.addPoint(-pi);
      expect(r, equals(mipi));
      r = S1Interval.empty();
      r = r.addPoint(pi);
      r = r.addPoint(-pi);
      expect(r, equals(piInterval));
      r = S1Interval.empty();
      r = r.addPoint(-pi);
      r = r.addPoint(pi);
      expect(r, equals(mipi));
      r = S1Interval.empty();
      r = r.addPoint(mid12.lo);
      r = r.addPoint(mid12.hi);
      expect(r, equals(mid12));
      r = S1Interval.empty();
      r = r.addPoint(mid23.lo);
      r = r.addPoint(mid23.hi);
      expect(r, equals(mid23));
      r = S1Interval.copy(quad1);
      r = r.addPoint(-0.9 * pi);
      r = r.addPoint(-mPi2);
      expect(r, equals(quad123));
      r = S1Interval.full();
      r = r.addPoint(0);
      expect(r.isFull, isTrue);
      r = S1Interval.full();
      r = r.addPoint(pi);
      expect(r.isFull, isTrue);
      r = S1Interval.full();
      r = r.addPoint(-pi);
      expect(r.isFull, isTrue);
    });

    test('testClampPoint', () {
      var r = S1Interval(-pi, -pi);
      assertExactly(pi, r.clampPoint(-pi));
      assertExactly(pi, r.clampPoint(0));
      r = S1Interval(0, pi);
      assertExactly(0.1, r.clampPoint(0.1));
      assertExactly(0.0, r.clampPoint(-mPi2 + 1e-15));
      assertExactly(pi, r.clampPoint(-mPi2 - 1e-15));
      r = S1Interval(pi - 0.1, -pi + 0.1);
      assertExactly(pi, r.clampPoint(pi));
      assertExactly(pi - 0.1, r.clampPoint(1e-15));
      assertExactly(-pi + 0.1, r.clampPoint(-1e-15));
      assertExactly(0.0, S1Interval.full().clampPoint(0));
      assertExactly(pi, S1Interval.full().clampPoint(pi));
      assertExactly(pi, S1Interval.full().clampPoint(-pi));
    });

    test('testFromPointPair', () {
      expect(S1Interval.fromPointPair(-pi, pi), equals(piInterval));
      expect(S1Interval.fromPointPair(pi, -pi), equals(piInterval));
      expect(S1Interval.fromPointPair(mid34.hi, mid34.lo), equals(mid34));
      expect(S1Interval.fromPointPair(mid23.lo, mid23.hi), equals(mid23));
    });

    test('testExpanded', () {
      expect(empty.expanded(1), equals(empty));
      expect(full.expanded(1), equals(full));
      expect(zero.expanded(1), equals(S1Interval(-1, 1)));
      expect(mipi.expanded(0.01), equals(S1Interval(pi - 0.01, -pi + 0.01)));
      expect(piInterval.expanded(27), equals(full));
      expect(piInterval.expanded(mPi2), equals(quad23));
      expect(pi2.expanded(mPi2), equals(quad12));
      expect(mipi2.expanded(mPi2), equals(quad34));

      expect(empty.expanded(-1), equals(empty));
      expect(full.expanded(-1), equals(full));
      expect(quad123.expanded(-27), equals(empty));
      expect(quad234.expanded(-27), equals(empty));
      expect(quad123.expanded(-mPi2), equals(quad2));
      expect(quad341.expanded(-mPi2), equals(quad4));
      expect(quad412.expanded(-mPi2), equals(quad1));
    });

    test('testApproxEquals', () {
      // Choose two values kLo and kHi such that it's okay to shift an endpoint by kLo
      // but not by kHi.
      final double kLo = 4 * S2.dblEpsilon; // < maxError default
      final double kHi = 6 * S2.dblEpsilon; // > maxError default

      // Empty intervals.
      expect(empty.approxEquals(empty), isTrue);
      expect(zero.approxEquals(empty) && empty.approxEquals(zero), isTrue);
      expect(piInterval.approxEquals(empty) && empty.approxEquals(piInterval), isTrue);
      expect(mipi.approxEquals(empty) && empty.approxEquals(mipi), isTrue);
      expect(empty.approxEquals(full), isFalse);
      expect(empty.approxEquals(S1Interval(1, 1 + 2 * kLo)), isTrue);
      expect(empty.approxEquals(S1Interval(1, 1 + 2 * kHi)), isFalse);
      expect(S1Interval(pi - kLo, -pi + kLo).approxEquals(empty), isTrue);

      // Full intervals.
      expect(full.approxEquals(full), isTrue);
      expect(full.approxEquals(empty), isFalse);
      expect(full.approxEquals(zero), isFalse);
      expect(full.approxEquals(piInterval), isFalse);
      expect(full.approxEquals(S1Interval(kLo, -kLo)), isTrue);
      expect(full.approxEquals(S1Interval(2 * kHi, 0)), isFalse);
      expect(S1Interval(-pi + kLo, pi - kLo).approxEquals(full), isTrue);
      expect(S1Interval(-pi, pi - 2 * kHi).approxEquals(full), isFalse);

      // Singleton intervals.
      expect(piInterval.approxEquals(piInterval) && mipi.approxEquals(piInterval), isTrue);
      expect(piInterval.approxEquals(S1Interval(pi - kLo, pi - kLo)), isTrue);
      expect(piInterval.approxEquals(S1Interval(pi - kHi, pi - kHi)), isFalse);
      expect(piInterval.approxEquals(S1Interval(pi - kLo, -pi + kLo)), isTrue);
      expect(piInterval.approxEquals(S1Interval(pi - kHi, -pi)), isFalse);
      expect(zero.approxEquals(piInterval), isFalse);
      expect(piInterval.union(mid12).union(zero).approxEquals(quad12), isTrue);
      expect(quad2.intersection(quad3).approxEquals(piInterval), isTrue);
      expect(quad3.intersection(quad2).approxEquals(piInterval), isTrue);

      // Intervals whose endpoints are in opposite order (inverted intervals).
      expect(S1Interval(0, kLo).approxEquals(S1Interval(kLo, 0)), isFalse);
      expect(
          S1Interval(pi - 0.5 * kLo, -pi + 0.5 * kLo)
              .approxEquals(S1Interval(-pi + 0.5 * kLo, pi - 0.5 * kLo)),
          isFalse);

      // Other intervals.
      expect(S1Interval(1 - kLo, 2 + kLo).approxEquals(S1Interval(1, 2)), isTrue);
      expect(S1Interval(1 + kLo, 2 - kLo).approxEquals(S1Interval(1, 2)), isTrue);
      expect(S1Interval(2 - kLo, 1 + kLo).approxEquals(S1Interval(2, 1)), isTrue);
      expect(S1Interval(2 + kLo, 1 - kLo).approxEquals(S1Interval(2, 1)), isTrue);
      expect(S1Interval(1 - kHi, 2 + kLo).approxEquals(S1Interval(1, 2)), isFalse);
      expect(S1Interval(1 + kHi, 2 - kLo).approxEquals(S1Interval(1, 2)), isFalse);
      expect(S1Interval(2 - kHi, 1 + kLo).approxEquals(S1Interval(2, 1)), isFalse);
      expect(S1Interval(2 + kHi, 1 - kLo).approxEquals(S1Interval(2, 1)), isFalse);
      expect(S1Interval(1 - kLo, 2 + kHi).approxEquals(S1Interval(1, 2)), isFalse);
      expect(S1Interval(1 + kLo, 2 - kHi).approxEquals(S1Interval(1, 2)), isFalse);
      expect(S1Interval(2 - kLo, 1 + kHi).approxEquals(S1Interval(2, 1)), isFalse);
      expect(S1Interval(2 + kLo, 1 - kHi).approxEquals(S1Interval(2, 1)), isFalse);
    });

    test('testGetDirectedHausdorffDistance', () {
      assertExactly(0.0, empty.getDirectedHausdorffDistance(empty));
      assertExactly(0.0, empty.getDirectedHausdorffDistance(mid12));
      assertExactly(pi, mid12.getDirectedHausdorffDistance(empty));

      assertExactly(0.0, quad12.getDirectedHausdorffDistance(quad123));
      final inInterval = S1Interval(3.0, -3.0); // complement center is 0.
      assertExactly(3.0, S1Interval(-0.1, 0.2).getDirectedHausdorffDistance(inInterval));
      assertExactly(3.0 - 0.1, S1Interval(0.1, 0.2).getDirectedHausdorffDistance(inInterval));
      assertExactly(3.0 - 0.1, S1Interval(-0.2, -0.1).getDirectedHausdorffDistance(inInterval));
    });
  });
}
