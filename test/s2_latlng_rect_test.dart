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
  });
}
