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

    test('testFromAxisArea', () {
      final cap = S2Cap.fromAxisArea(S2Point(1, 0, 0), 2 * math.pi);
      expect(cap.area, closeTo(2 * math.pi, 1e-10));
    });

    test('testArea', () {
      final full = S2Cap.full();
      expect(full.area, closeTo(4 * math.pi, 1e-10));
      final hemi = S2Cap.fromAxisHeight(S2Point(0, 0, 1), 1);
      expect(hemi.area, closeTo(2 * math.pi, 1e-10));
    });

    test('testAddPoint', () {
      final empty = S2Cap.empty();
      final point = S2Point(1, 0, 0);
      final cap = empty.addPoint(point);
      expect(cap.radius.isZero, isTrue);

      final cap2 = cap.addPoint(S2Point(0, 1, 0));
      expect(cap2.radius.length2, greaterThan(0));
    });

    test('testAddCap', () {
      final cap1 = S2Cap.fromAxisAngle(S2Point(1, 0, 0), S1Angle.degrees(10));
      final cap2 = S2Cap.fromAxisAngle(S2Point(0, 1, 0), S1Angle.degrees(10));
      final combined = cap1.addCap(cap2);
      expect(combined.radius.length2, greaterThan(cap1.radius.length2));

      // Add empty cap returns original
      final empty = S2Cap.empty();
      expect(cap1.addCap(empty), equals(cap1));
      expect(empty.addCap(cap1), equals(cap1));
    });

    test('testIntersectsCap', () {
      final cap1 = S2Cap.fromAxisAngle(S2Point(1, 0, 0), S1Angle.degrees(45));
      final cap2 = S2Cap.fromAxisAngle(S2Point(0, 1, 0), S1Angle.degrees(45));
      expect(cap1.intersectsCap(cap2), isFalse); // Too far apart

      final cap3 = S2Cap.fromAxisAngle(S2Point(1, 0, 0), S1Angle.degrees(60));
      final cap4 = S2Cap.fromAxisAngle(S2Point(0, 1, 0), S1Angle.degrees(60));
      expect(cap3.intersectsCap(cap4), isTrue); // Close enough to intersect

      final empty = S2Cap.empty();
      expect(cap1.intersectsCap(empty), isFalse);
      expect(empty.intersectsCap(cap1), isFalse);
    });

    test('testCapBound', () {
      final cap = S2Cap.fromAxisAngle(S2Point(1, 0, 0), S1Angle.degrees(45));
      expect(cap.capBound, equals(cap));
    });

    test('testGetCellUnionBound', () {
      final cap = S2Cap.fromAxisAngle(S2Point(1, 0, 0), S1Angle.degrees(10));
      final cells = <S2CellId>[];
      cap.getCellUnionBound(cells);
      expect(cells, isNotEmpty);
    });

    test('testGetCellUnionBoundLarge', () {
      // A large cap should get all face cells
      final cap = S2Cap.fromAxisAngle(S2Point(1, 0, 0), S1Angle.degrees(120));
      final cells = <S2CellId>[];
      cap.getCellUnionBound(cells);
      expect(cells.length, equals(6)); // All 6 face cells
    });

    test('testMayIntersectCell', () {
      final cap = S2Cap.fromAxisAngle(S2Point(1, 0, 0), S1Angle.degrees(45));
      final cell = S2Cell(S2CellId.fromFace(0));
      expect(cap.mayIntersect(cell), isTrue);
    });

    test('testContainsCell', () {
      // A full cap contains any cell
      final full = S2Cap.full();
      final cell = S2Cell(S2CellId.fromFace(0));
      expect(full.containsCell(cell), isTrue);

      // Small cap doesn't contain large cell
      final smallCap = S2Cap.fromAxisAngle(S2Point(1, 0, 0), S1Angle.degrees(1));
      expect(smallCap.containsCell(cell), isFalse);
    });

    test('testHashCode', () {
      final cap1 = S2Cap.fromAxisAngle(S2Point(1, 0, 0), S1Angle.degrees(45));
      final cap2 = S2Cap.fromAxisAngle(S2Point(1, 0, 0), S1Angle.degrees(45));
      expect(cap1.hashCode, equals(cap2.hashCode));

      // Special cases
      expect(S2Cap.empty().hashCode, equals(S2Cap.empty().hashCode));
      expect(S2Cap.full().hashCode, equals(S2Cap.full().hashCode));
    });

    test('testToString', () {
      final cap = S2Cap.fromAxisAngle(S2Point(1, 0, 0), S1Angle.degrees(45));
      final str = cap.toString();
      expect(str, contains('Point'));
      expect(str, contains('Radius'));
    });

    test('testApproxEqualsWithError', () {
      final cap1 = S2Cap.fromAxisAngle(S2Point(1, 0, 0), S1Angle.degrees(45));
      final cap2 = S2Cap.fromAxisAngle(S2Point(1, 0, 0), S1Angle.degrees(45.001));
      expect(cap1.approxEqualsWithError(cap2, 0.1), isTrue);
      expect(cap1.approxEqualsWithError(cap2, 1e-10), isFalse);

      // Empty caps
      expect(S2Cap.empty().approxEqualsWithError(S2Cap.empty(), 0.1), isTrue);

      // Full caps
      expect(S2Cap.full().approxEqualsWithError(S2Cap.full(), 0.1), isTrue);
    });

    test('testEquality', () {
      final cap1 = S2Cap.fromAxisAngle(S2Point(1, 0, 0), S1Angle.degrees(45));
      final cap2 = S2Cap.fromAxisAngle(S2Point(1, 0, 0), S1Angle.degrees(45));
      expect(cap1, equals(cap2));

      // Empty caps are equal
      expect(S2Cap.empty(), equals(S2Cap.empty()));

      // Full caps are equal
      expect(S2Cap.full(), equals(S2Cap.full()));

      expect(cap1 == "not a cap", isFalse);
    });

    test('testRectBoundEmpty', () {
      // Empty cap returns empty rect
      final empty = S2Cap.empty();
      final rect = empty.rectBound;
      expect(rect.isEmpty, isTrue);
    });

    test('testRectBoundFull', () {
      // Full cap returns full rect
      final full = S2Cap.full();
      final rect = full.rectBound;
      expect(rect.isFull, isTrue);
    });

    test('testRectBoundNotImplemented', () {
      // Non-empty, non-full caps throw UnimplementedError
      final cap = S2Cap.fromAxisAngle(S2Point(1, 0, 0), S1Angle.degrees(45));
      expect(() => cap.rectBound, throwsUnimplementedError);
    });
  });
}
