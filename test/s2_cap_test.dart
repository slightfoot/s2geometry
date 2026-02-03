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

/// Tests for S2Cap.
/// Ported from S2CapTest.java
library;

import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:s2geometry/s2geometry.dart';

import 'geometry_test_case.dart';

S2Point getLatLngPoint(double latDegrees, double lngDegrees) {
  return S2LatLng.fromDegrees(latDegrees, lngDegrees).toPoint();
}

// About 9 times the double-precision roundoff relative error.
const double eps = 1e-15;

void main() {
  group('S2Cap', () {
    test('testBasicEmptyAndFull', () {
      // Test basic properties of empty and full caps.
      final empty = S2Cap.empty();
      final full = S2Cap.full();

      expect(empty.isValid, isTrue);
      expect(empty.isEmpty, isTrue);
      expect(empty.complement.isFull, isTrue);

      expect(full.isValid, isTrue);
      expect(full.isFull, isTrue);
      expect(full.complement.isEmpty, isTrue);

      assertExactly(2.0, full.height);
      assertAlmostEquals(full.angle.degrees, 180.0);
    });

    test('testAxisAngleConstructorOutOfRange', () {
      // Test the S1Angle constructor using out-of-range arguments.
      expect(S2Cap.fromAxisAngle(S2Point.xPos, S1Angle.radians(-20)).isEmpty, isTrue);
      expect(S2Cap.fromAxisAngle(S2Point.xPos, S1Angle.radians(5)).isFull, isTrue);
      expect(S2Cap.fromAxisAngle(S2Point.xPos, S1Angle.infinity).isFull, isTrue);
    });

    test('testEmptyAndFullContainment', () {
      final empty = S2Cap.empty();
      final full = S2Cap.full();

      // Containment and intersection of empty and full caps.
      expect(empty.containsCap(empty), isTrue);
      expect(full.containsCap(empty), isTrue);
      expect(full.containsCap(full), isTrue);
      expect(empty.interiorIntersects(empty), isFalse);
      expect(full.interiorIntersects(full), isTrue);
      expect(full.interiorIntersects(empty), isFalse);
    });

    test('testSingletonCap', () {
      // Singleton cap containing the x-axis.
      final xaxis = S2Cap.fromAxisHeight(S2Point(1, 0, 0), 0);
      expect(xaxis.containsPoint(S2Point(1, 0, 0)), isTrue);
      expect(xaxis.containsPoint(S2Point(1, 1e-20, 0)), isFalse);
      assertExactly(0.0, xaxis.angle.radians);

      // Singleton cap containing the y-axis.
      final yaxis = S2Cap.fromAxisAngle(S2Point(0, 1, 0), S1Angle.radians(0));
      expect(yaxis.containsPoint(xaxis.axis), isFalse);
      assertExactly(0.0, xaxis.height);
    });

    test('testSingletonComplement', () {
      final xaxis = S2Cap.fromAxisHeight(S2Point(1, 0, 0), 0);

      // Check that the complement of a singleton cap is the full cap.
      final xcomp = xaxis.complement;
      expect(xcomp.isValid, isTrue);
      expect(xcomp.isFull, isTrue);
      expect(xcomp.containsPoint(xaxis.axis), isTrue);

      // Check that the complement of the complement is *not* the original.
      expect(xcomp.complement.isValid, isTrue);
      expect(xcomp.complement.isEmpty, isTrue);
      expect(xcomp.complement.containsPoint(xaxis.axis), isFalse);
    });

    test('testTinyCap', () {
      // Check that very small caps can be represented accurately.
      const kTinyRad = 1e-10;
      final tiny = S2Cap.fromAxisAngle(
        S2Point(1, 2, 3).normalize(),
        S1Angle.radians(kTinyRad),
      );
      final tangent = tiny.axis.crossProd(S2Point(3, 2, 1)).normalize();
      expect(tiny.containsPoint((tiny.axis + tangent * (0.99 * kTinyRad)).normalize()), isTrue);
      expect(tiny.containsPoint((tiny.axis + tangent * (1.01 * kTinyRad)).normalize()), isFalse);
    });

    test('testHemisphericalCap', () {
      // Basic tests on a hemispherical cap.
      final hemi = S2Cap.fromAxisHeight(S2Point(1, 0, 1).normalize(), 1);
      expect(hemi.complement.axis, equals(hemi.axis.neg()));
      expect(hemi.complement.height, closeTo(1.0, 1e-15));
      expect(hemi.containsPoint(S2Point(1, 0, 0)), isTrue);
      expect(hemi.complement.containsPoint(S2Point(1, 0, 0)), isFalse);
      expect(hemi.containsPoint(S2Point(1, 0, -(1 - eps)).normalize()), isTrue);
      expect(hemi.interiorContains(S2Point(1, 0, -(1 + eps)).normalize()), isFalse);
    });

    test('testCapContainment', () {
      final empty = S2Cap.empty();
      final full = S2Cap.full();
      final xaxis = S2Cap.fromAxisHeight(S2Point(1, 0, 0), 0);
      final hemi = S2Cap.fromAxisHeight(S2Point(1, 0, 1).normalize(), 1);
      const kTinyRad = 1e-10;
      final tiny = S2Cap.fromAxisAngle(
        S2Point(1, 2, 3).normalize(),
        S1Angle.radians(kTinyRad),
      );

      expect(empty.containsCap(xaxis), isFalse);
      expect(empty.interiorIntersects(xaxis), isFalse);
      expect(full.containsCap(xaxis), isTrue);
      expect(full.interiorIntersects(xaxis), isTrue);
      expect(xaxis.containsCap(full), isFalse);
      expect(xaxis.interiorIntersects(full), isFalse);
      expect(xaxis.containsCap(xaxis), isTrue);
      expect(xaxis.interiorIntersects(xaxis), isFalse);
      expect(xaxis.containsCap(empty), isTrue);
      expect(xaxis.interiorIntersects(empty), isFalse);
      expect(hemi.containsCap(tiny), isTrue);
      expect(
          hemi.containsCap(
              S2Cap.fromAxisAngle(S2Point(1, 0, 0), S1Angle.radians(S2.piOver4 - eps))),
          isTrue);
      expect(
          hemi.containsCap(
              S2Cap.fromAxisAngle(S2Point(1, 0, 0), S1Angle.radians(S2.piOver4 + eps))),
          isFalse);
    });

    test('testExpanded', () {
      expect(S2Cap.empty().expanded(S1Angle.radians(2)).isEmpty, isTrue);
      expect(S2Cap.full().expanded(S1Angle.radians(2)).isFull, isTrue);
      final cap50 = S2Cap.fromAxisAngle(S2Point(1, 0, 0), S1Angle.degrees(50));
      final cap51 = S2Cap.fromAxisAngle(S2Point(1, 0, 0), S1Angle.degrees(51));
      expect(cap50.expanded(S1Angle.radians(0)).approxEquals(cap50), isTrue);
      expect(cap50.expanded(S1Angle.degrees(1)).approxEquals(cap51), isTrue);
      expect(cap50.expanded(S1Angle.degrees(129.99)).isFull, isFalse);
      expect(cap50.expanded(S1Angle.degrees(130.01)).isFull, isTrue);
    });
  });
}
