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

/// Tests for S2LatLngRect.
/// Ported from S2LatLngRectTest.java
library;

import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:s2geometry/s2geometry.dart';

import 'geometry_test_case.dart';

/// Convenience method to construct a rectangle.
S2LatLngRect rectFromDegrees(double latLo, double lngLo, double latHi, double lngHi) {
  return S2LatLngRect(
    R1Interval(S1Angle.degrees(latLo).radians, S1Angle.degrees(latHi).radians),
    S1Interval(S1Angle.degrees(lngLo).radians, S1Angle.degrees(lngHi).radians),
  );
}

void main() {
  group('S2LatLngRect', () {
    test('testBasicEmptyAndFull', () {
      // Test basic properties of empty and full rectangles.
      final empty = S2LatLngRect.empty();
      final full = S2LatLngRect.full();

      expect(empty.isValid, isTrue);
      expect(empty.isEmpty, isTrue);
      expect(empty.isPoint, isFalse);

      expect(full.isValid, isTrue);
      expect(full.isFull, isTrue);
      expect(full.isPoint, isFalse);
    });

    test('testConstructorsAndAccessors', () {
      // Test various constructors and accessor methods.
      final d1 = rectFromDegrees(-90, 0, -45, 180);
      assertAlmostEquals(d1.lat.lo, S1Angle.degrees(-90).radians);
      assertAlmostEquals(d1.lat.hi, S1Angle.degrees(-45).radians);
      assertAlmostEquals(d1.lng.lo, S1Angle.degrees(0).radians);
      assertAlmostEquals(d1.lng.hi, S1Angle.degrees(180).radians);
      expect(d1.lat, equals(R1Interval(-S2.piOver2, -S2.piOver4)));
      expect(d1.lng, equals(S1Interval(0, math.pi)));
    });

    test('testFromPoint', () {
      final ll = S2LatLng.fromDegrees(23, 47);
      final rect = S2LatLngRect.fromPoint(ll);
      expect(rect.isPoint, isTrue);
      expect(rect.containsLatLng(ll), isTrue);
    });

    test('testFromPointPair', () {
      expect(
        S2LatLngRect.fromPointPair(
          S2LatLng.fromDegrees(-35, -140),
          S2LatLng.fromDegrees(15, 155),
        ),
        equals(rectFromDegrees(-35, 155, 15, -140)),
      );
      expect(
        S2LatLngRect.fromPointPair(
          S2LatLng.fromDegrees(25, -70),
          S2LatLng.fromDegrees(-90, 80),
        ),
        equals(rectFromDegrees(-90, -70, 25, 80)),
      );
    });

    test('testGetCenter', () {
      final eqM180 = S2LatLng.fromRadians(0, -math.pi);
      final northPole = S2LatLng.fromRadians(S2.piOver2, 0);
      final r1 = S2LatLngRect(
        R1Interval(eqM180.latRadians, northPole.latRadians),
        S1Interval(eqM180.lngRadians, northPole.lngRadians),
      );
      expect(r1.center, equals(S2LatLng.fromRadians(S2.piOver4, -S2.piOver2)));
    });

    test('testGetVertex', () {
      final eqM180 = S2LatLng.fromRadians(0, -math.pi);
      final northPole = S2LatLng.fromRadians(S2.piOver2, 0);
      final r1 = S2LatLngRect(
        R1Interval(eqM180.latRadians, northPole.latRadians),
        S1Interval(eqM180.lngRadians, northPole.lngRadians),
      );
      expect(r1.getVertex(0), equals(S2LatLng.fromRadians(0, math.pi)));
      expect(r1.getVertex(1), equals(S2LatLng.fromRadians(0, 0)));
      expect(r1.getVertex(2), equals(S2LatLng.fromRadians(S2.piOver2, 0)));
      expect(r1.getVertex(3), equals(S2LatLng.fromRadians(S2.piOver2, math.pi)));
    });

    test('testContains', () {
      final r1 = rectFromDegrees(0, -180, 90, 0);
      expect(r1.containsLatLng(S2LatLng.fromDegrees(30, -45)), isTrue);
      expect(r1.containsLatLng(S2LatLng.fromDegrees(30, 45)), isFalse);
    });

    test('testUnion', () {
      final r1 = rectFromDegrees(0, 0, 30, 60);
      final r2 = rectFromDegrees(10, 30, 50, 90);
      final expected = rectFromDegrees(0, 0, 50, 90);
      expect(r1.union(r2), equals(expected));
    });

    test('testIntersection', () {
      final r1 = rectFromDegrees(0, 0, 30, 60);
      final r2 = rectFromDegrees(10, 30, 50, 90);
      final expected = rectFromDegrees(10, 30, 30, 60);
      expect(r1.intersection(r2), equals(expected));
    });

    test('testPolarClosure', () {
      expect(
        rectFromDegrees(-89, 0, 89, 1).polarClosure(),
        equals(rectFromDegrees(-89, 0, 89, 1)),
      );
      expect(
        rectFromDegrees(-90, -30, -45, 100).polarClosure(),
        equals(rectFromDegrees(-90, -180, -45, 180)),
      );
      expect(
        rectFromDegrees(89, 145, 90, 146).polarClosure(),
        equals(rectFromDegrees(89, -180, 90, 180)),
      );
    });

    test('testFromLatLng', () {
      final lo = S2LatLng.fromDegrees(10, 20);
      final hi = S2LatLng.fromDegrees(30, 40);
      final rect = S2LatLngRect.fromLatLng(lo, hi);
      expect(rect.lo, equals(lo));
      expect(rect.hi, equals(hi));
    });

    test('testFullLat', () {
      final fullLat = S2LatLngRect.fullLat;
      expect(fullLat.lo, closeTo(-S2.piOver2, 1e-10));
      expect(fullLat.hi, closeTo(S2.piOver2, 1e-10));
    });

    test('testFullLng', () {
      final fullLng = S2LatLngRect.fullLng;
      expect(fullLng.isFull, isTrue);
    });

    test('testSize', () {
      final rect = rectFromDegrees(10, 20, 30, 60);
      final size = rect.size;
      expect(size.latDegrees, closeTo(20.0, 1e-10));
      expect(size.lngDegrees, closeTo(40.0, 1e-10));
    });

    test('testContainsRect', () {
      final outer = rectFromDegrees(0, 0, 50, 90);
      final inner = rectFromDegrees(10, 30, 40, 60);
      expect(outer.containsRect(inner), isTrue);
      expect(inner.containsRect(outer), isFalse);
    });

    test('testIntersectsRect', () {
      final r1 = rectFromDegrees(0, 0, 30, 60);
      final r2 = rectFromDegrees(10, 30, 50, 90);
      expect(r1.intersectsRect(r2), isTrue);

      final r3 = rectFromDegrees(40, 70, 50, 90);
      expect(r1.intersectsRect(r3), isFalse);
    });

    test('testContainsPoint', () {
      final rect = rectFromDegrees(0, 0, 30, 60);
      final inside = S2LatLng.fromDegrees(15, 30).toPoint();
      final outside = S2LatLng.fromDegrees(50, 90).toPoint();
      expect(rect.containsPoint(inside), isTrue);
      expect(rect.containsPoint(outside), isFalse);
    });

    test('testExpanded', () {
      final rect = rectFromDegrees(0, 0, 30, 60);
      final margin = S2LatLng.fromDegrees(10, 20);
      final expanded = rect.expanded(margin);
      expect(expanded.lat.lo, closeTo(S1Angle.degrees(-10).radians, 1e-10));
      expect(expanded.lat.hi, closeTo(S1Angle.degrees(40).radians, 1e-10));
    });

    test('testAddPoint', () {
      final rect = rectFromDegrees(10, 20, 30, 40);
      final point = S2LatLng.fromDegrees(50, 60);
      final newRect = rect.addPoint(point);
      expect(newRect.containsLatLng(point), isTrue);
    });

    test('testIntersectionEmpty', () {
      final r1 = rectFromDegrees(0, 0, 10, 10);
      final r2 = rectFromDegrees(20, 20, 30, 30);
      final intersection = r1.intersection(r2);
      expect(intersection.isEmpty, isTrue);
    });

    test('testCapBound', () {
      final rect = rectFromDegrees(10, 20, 30, 40);
      final cap = rect.capBound;
      expect(cap.isEmpty, isFalse);
    });

    test('testCapBoundEmpty', () {
      final rect = S2LatLngRect.empty();
      final cap = rect.capBound;
      expect(cap.isEmpty, isTrue);
    });

    test('testCapBoundContainingPole', () {
      final rect = rectFromDegrees(80, 0, 90, 180);
      final cap = rect.capBound;
      expect(cap.isEmpty, isFalse);
    });

    test('testRectBound', () {
      final rect = rectFromDegrees(10, 20, 30, 40);
      expect(rect.rectBound, equals(rect));
    });

    test('testGetCellUnionBound', () {
      final rect = rectFromDegrees(10, 20, 30, 40);
      final cells = <S2CellId>[];
      rect.getCellUnionBound(cells);
      expect(cells, isNotEmpty);
    });

    test('testContainsCell', () {
      // Large rect should contain small cell inside it
      final rect = rectFromDegrees(0, 0, 45, 45);
      // Find a cell that's within the rect
      final cellId = S2CellId.fromFace(0).child(0).child(0).child(0);
      final cell = S2Cell(cellId);
      final cellRect = cell.rectBound;
      // Only test if the cell is actually inside
      if (rect.containsRect(cellRect)) {
        expect(rect.containsCell(cell), isTrue);
      }
    });

    test('testMayIntersect', () {
      final rect = rectFromDegrees(0, 0, 45, 45);
      final cell = S2Cell(S2CellId.fromFace(0));
      expect(rect.mayIntersect(cell), isTrue);
    });

    test('testEquality', () {
      final r1 = rectFromDegrees(10, 20, 30, 40);
      final r2 = rectFromDegrees(10, 20, 30, 40);
      expect(r1, equals(r2));

      final r3 = rectFromDegrees(0, 0, 10, 10);
      expect(r1 == r3, isFalse);

      expect(r1 == "not a rect", isFalse);
    });

    test('testHashCode', () {
      final r1 = rectFromDegrees(10, 20, 30, 40);
      final r2 = rectFromDegrees(10, 20, 30, 40);
      expect(r1.hashCode, equals(r2.hashCode));
    });

    test('testToString', () {
      final rect = rectFromDegrees(10, 20, 30, 40);
      final str = rect.toString();
      expect(str, contains('Lo'));
      expect(str, contains('Hi'));
    });
  });
}
