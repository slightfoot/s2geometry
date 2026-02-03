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

/// Tests for R2Rect.
/// Ported from R2RectTest.java
library;

import 'package:test/test.dart';
import 'package:s2geometry/s2geometry.dart';

import 'geometry_test_case.dart';

/// Tests all of the interval operations on the given pair of rectangles.
void testIntervalOps(
    R2Rect x,
    R2Rect y,
    String expectedRexion,
    R2Rect expectedUnion,
    R2Rect expectedIntersection) {
  expect(x.contains(y), equals(expectedRexion[0] == 'T'));
  expect(x.interiorContains(y), equals(expectedRexion[1] == 'T'));
  expect(x.intersects(y), equals(expectedRexion[2] == 'T'));
  expect(x.interiorIntersects(y), equals(expectedRexion[3] == 'T'));

  expect(x.union(y) == x, equals(x.contains(y)));
  expect(!x.intersection(y).isEmpty, equals(x.intersects(y)));

  expect(x.union(y), equals(expectedUnion));
  expect(x.intersection(y), equals(expectedIntersection));

  final r = R2Rect.copy(x);
  r.addRect(y);
  expect(r, equals(expectedUnion));
  
  if (y.getSize() == R2Vector(0, 0)) {
    final r2 = R2Rect.copy(x);
    r2.addPoint(y.lo);
    expect(r2, equals(expectedUnion));
  }
}

void main() {
  group('R2Rect', () {
    test('testEmptyRectangles', () {
      final empty = R2Rect.empty();
      expect(empty.isValid, isTrue);
      expect(empty.isEmpty, isTrue);
    });

    test('testConstructorsAndAccessors', () {
      final r = R2Rect.fromVectors(R2Vector(0.1, 0), R2Vector(0.25, 1));
      assertExactly(0.1, r.x.lo);
      assertExactly(0.25, r.x.hi);
      assertExactly(0.0, r.y.lo);
      assertExactly(1.0, r.y.hi);

      assertExactly(0.1, r.getInterval(Axis.X).getValue(Endpoint.LO));
      assertExactly(0.25, r.getInterval(Axis.X).getValue(Endpoint.HI));
      assertExactly(0.0, r.getInterval(Axis.Y).getValue(Endpoint.LO));
      assertExactly(1.0, r.getInterval(Axis.Y).getValue(Endpoint.HI));

      expect(r.x, equals(R1Interval(0.1, 0.25)));
      expect(r.y, equals(R1Interval(0, 1)));

      expect(r.getInterval(Axis.X), equals(R1Interval(0.1, 0.25)));
      expect(r.getInterval(Axis.Y), equals(R1Interval(0, 1)));

      r.getInterval(Axis.X).set(3, 4);
      expect(r.getInterval(Axis.X), equals(R1Interval(3, 4)));
      r.getInterval(Axis.Y).setValue(Endpoint.LO, 5);
      r.getInterval(Axis.Y).setValue(Endpoint.HI, 6);
      expect(r.getInterval(Axis.Y), equals(R1Interval(5, 6)));

      final r2 = R2Rect.empty();
      expect(r2.isEmpty, isTrue);
    });

    test('testFromCenterSize', () {
      expect(
          R2Rect.fromCenterSize(R2Vector(0.3, 0.5), R2Vector(0.2, 0.4))
              .approxEquals(R2Rect.fromVectors(R2Vector(0.2, 0.3), R2Vector(0.4, 0.7))),
          isTrue);
      expect(
          R2Rect.fromCenterSize(R2Vector(1, 0.1), R2Vector(0, 2))
              .approxEquals(R2Rect.fromVectors(R2Vector(1, -0.9), R2Vector(1, 1.1))),
          isTrue);
    });

    test('testFromPoint', () {
      final d1 = R2Rect.fromVectors(R2Vector(0.1, 0), R2Vector(0.25, 1));
      expect(R2Rect.fromPoint(d1.lo), equals(R2Rect.fromVectors(d1.lo, d1.lo)));
      expect(
          R2Rect.fromPointPair(R2Vector(0.15, 0.9), R2Vector(0.35, 0.3)),
          equals(R2Rect.fromVectors(R2Vector(0.15, 0.3), R2Vector(0.35, 0.9))));
      expect(
          R2Rect.fromPointPair(R2Vector(0.83, 0), R2Vector(0.12, 0.5)),
          equals(R2Rect.fromVectors(R2Vector(0.12, 0), R2Vector(0.83, 0.5))));
    });

    test('testSimplePredicates', () {
      final sw1 = R2Vector(0, 0.25);
      final ne1 = R2Vector(0.5, 0.75);
      final r1 = R2Rect.fromVectors(sw1, ne1);

      expect(r1.getCenter(), equals(R2Vector(0.25, 0.5)));
      expect(r1.getVertex(0), equals(R2Vector(0, 0.25)));
      expect(r1.getVertex(1), equals(R2Vector(0.5, 0.25)));
      expect(r1.getVertex(2), equals(R2Vector(0.5, 0.75)));
      expect(r1.getVertex(3), equals(R2Vector(0, 0.75)));
      expect(r1.contains(R2Vector(0.2, 0.4)), isTrue);
      expect(r1.contains(R2Vector(0.2, 0.8)), isFalse);
      expect(r1.contains(R2Vector(-0.1, 0.4)), isFalse);
      expect(r1.contains(R2Vector(0.6, 0.1)), isFalse);
      expect(r1.contains(sw1), isTrue);
      expect(r1.contains(ne1), isTrue);
      expect(r1.interiorContains(sw1), isFalse);
      expect(r1.interiorContains(ne1), isFalse);

      // Make sure that getVertex() returns vertices in CCW order and reduces the argument modulo 4.
      for (var k = 0; k < 8; ++k) {
        final a = r1.getVertex((k - 1) & 3);
        final b = r1.getVertex(k);
        final c = r1.getVertex((k + 1) & 3);
        expect(b.sub(a).ortho().dotProd(c.sub(a)) > 0, isTrue);
      }
    });

    test('testIntervalOperations', () {
      final empty = R2Rect.empty();
      final sw1 = R2Vector(0, 0.25);
      final ne1 = R2Vector(0.5, 0.75);
      final r1 = R2Rect.fromVectors(sw1, ne1);
      final r1Mid = R2Rect.fromVectors(R2Vector(0.25, 0.5), R2Vector(0.25, 0.5));
      final rSw1 = R2Rect.fromVectors(sw1, sw1);
      final rNe1 = R2Rect.fromVectors(ne1, ne1);

      testIntervalOps(r1, r1Mid, "TTTT", r1, r1Mid);
      testIntervalOps(r1, rSw1, "TFTF", r1, rSw1);
      testIntervalOps(r1, rNe1, "TFTF", r1, rNe1);

      expect(r1, equals(R2Rect.fromVectors(R2Vector(0, 0.25), R2Vector(0.5, 0.75))));
      testIntervalOps(
          r1,
          R2Rect.fromVectors(R2Vector(0.45, 0.1), R2Vector(0.75, 0.3)),
          "FFTT",
          R2Rect.fromVectors(R2Vector(0, 0.1), R2Vector(0.75, 0.75)),
          R2Rect.fromVectors(R2Vector(0.45, 0.25), R2Vector(0.5, 0.3)));
      testIntervalOps(
          r1,
          R2Rect.fromVectors(R2Vector(0.5, 0.1), R2Vector(0.7, 0.3)),
          "FFTF",
          R2Rect.fromVectors(R2Vector(0, 0.1), R2Vector(0.7, 0.75)),
          R2Rect.fromVectors(R2Vector(0.5, 0.25), R2Vector(0.5, 0.3)));
      testIntervalOps(
          r1,
          R2Rect.fromVectors(R2Vector(0.45, 0.1), R2Vector(0.7, 0.25)),
          "FFTF",
          R2Rect.fromVectors(R2Vector(0, 0.1), R2Vector(0.7, 0.75)),
          R2Rect.fromVectors(R2Vector(0.45, 0.25), R2Vector(0.5, 0.25)));

      testIntervalOps(
          R2Rect.fromVectors(R2Vector(0.1, 0.2), R2Vector(0.1, 0.3)),
          R2Rect.fromVectors(R2Vector(0.15, 0.7), R2Vector(0.2, 0.8)),
          "FFFF",
          R2Rect.fromVectors(R2Vector(0.1, 0.2), R2Vector(0.2, 0.8)),
          empty);

      // Check that the intersection of two rectangles that overlap in x but not y
      // is valid, and vice versa.
      testIntervalOps(
          R2Rect.fromVectors(R2Vector(0.1, 0.2), R2Vector(0.4, 0.5)),
          R2Rect.fromVectors(R2Vector(0, 0), R2Vector(0.2, 0.1)),
          "FFFF",
          R2Rect.fromVectors(R2Vector(0, 0), R2Vector(0.4, 0.5)),
          empty);
      testIntervalOps(
          R2Rect.fromVectors(R2Vector(0, 0), R2Vector(0.1, 0.3)),
          R2Rect.fromVectors(R2Vector(0.2, 0.1), R2Vector(0.3, 0.4)),
          "FFFF",
          R2Rect.fromVectors(R2Vector(0, 0), R2Vector(0.3, 0.4)),
          empty);
    });

    test('testAddPoint', () {
      final sw1 = R2Vector(0, 0.25);
      final ne1 = R2Vector(0.5, 0.75);
      final r1 = R2Rect.fromVectors(sw1, ne1);
      final r2 = R2Rect.empty();
      r2.addPoint(R2Vector(0, 0.25));
      r2.addPoint(R2Vector(0.5, 0.25));
      r2.addPoint(R2Vector(0, 0.75));
      r2.addPoint(R2Vector(0.1, 0.4));
      expect(r2, equals(r1));
    });

    test('testClampPoint', () {
      final r1 = R2Rect(R1Interval(0, 0.5), R1Interval(0.25, 0.75));
      expect(r1.clampPoint(R2Vector(-0.01, 0.24)), equals(R2Vector(0, 0.25)));
      expect(r1.clampPoint(R2Vector(-5.0, 0.48)), equals(R2Vector(0, 0.48)));
      expect(r1.clampPoint(R2Vector(-5.0, 2.48)), equals(R2Vector(0, 0.75)));
      expect(r1.clampPoint(R2Vector(0.19, 2.48)), equals(R2Vector(0.19, 0.75)));
      expect(r1.clampPoint(R2Vector(6.19, 2.48)), equals(R2Vector(0.5, 0.75)));
      expect(r1.clampPoint(R2Vector(6.19, 0.53)), equals(R2Vector(0.5, 0.53)));
      expect(r1.clampPoint(R2Vector(6.19, -2.53)), equals(R2Vector(0.5, 0.25)));
      expect(r1.clampPoint(R2Vector(0.33, -2.53)), equals(R2Vector(0.33, 0.25)));
      expect(r1.clampPoint(R2Vector(0.33, 0.37)), equals(R2Vector(0.33, 0.37)));
    });

    test('testExpanded', () {
      expect(R2Rect.empty().expanded(R2Vector(0.1, 0.3)).isEmpty, isTrue);
      expect(R2Rect.empty().expanded(R2Vector(-0.1, -0.3)).isEmpty, isTrue);
      expect(
          R2Rect.fromVectors(R2Vector(0.2, 0.4), R2Vector(0.3, 0.7))
              .expanded(R2Vector(0.1, 0.3))
              .approxEquals(R2Rect.fromVectors(R2Vector(0.1, 0.1), R2Vector(0.4, 1.0))),
          isTrue);
      expect(
          R2Rect.fromVectors(R2Vector(0.2, 0.4), R2Vector(0.3, 0.7))
              .expanded(R2Vector(-0.1, 0.3))
              .isEmpty,
          isTrue);
      expect(
          R2Rect.fromVectors(R2Vector(0.2, 0.4), R2Vector(0.3, 0.7))
              .expanded(R2Vector(0.1, -0.2))
              .isEmpty,
          isTrue);
      expect(
          R2Rect.fromVectors(R2Vector(0.2, 0.4), R2Vector(0.3, 0.7))
              .expanded(R2Vector(0.1, -0.1))
              .approxEquals(R2Rect.fromVectors(R2Vector(0.1, 0.5), R2Vector(0.4, 0.6))),
          isTrue);
      expect(
          R2Rect.fromVectors(R2Vector(0.2, 0.4), R2Vector(0.3, 0.7))
              .expanded(0.1)
              .approxEquals(R2Rect.fromVectors(R2Vector(0.1, 0.3), R2Vector(0.4, 0.8))),
          isTrue);
    });
  });
}

