// Copyright 2005 Google Inc.
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

/// Tests for S2Earth.

import 'dart:math' as math;
import 'package:test/test.dart';
import 'package:s2geometry/s2geometry.dart';

void main() {
  group('S2Earth', () {
    test('testAngleConversion', () {
      expect(
          S2Earth.toMetersFromAngle(S1Angle.degrees(180)),
          closeTo(S2Earth.radiusMeters * math.pi, 0));
      expect(
          S2Earth.toKm(S1Angle.radians(0.5)),
          closeTo(0.5 * S2Earth.radiusKm, 0));
      expect(
          S2Earth.kmToRadians(S2Earth.radiusMeters / 1000),
          closeTo(1, 0));
      expect(
          S2Earth.radiansToKm(0.5),
          closeTo(0.5 * S2Earth.radiusKm, 0));
      expect(
          S2Earth.metersToRadians(S2Earth.radiansToKm(0.3) * 1000),
          closeTo(0.3, 0));
      expect(
          S2Earth.radiansToMeters(S2Earth.kmToRadians(2.5)),
          closeTo(2500, 0));
    });

    test('testChordAngleConversion', () {
      const chordAngleEpsilon = 1e-15;
      final quarterCircumferenceMeters = S2Earth.radiusMeters * math.pi / 2.0;
      expect(
          S2Earth.metersToChordAngle(quarterCircumferenceMeters).length2,
          closeTo(2, chordAngleEpsilon));
      expect(
          S2Earth.toMetersFromChordAngle(S1ChordAngle.fromRadians(2)),
          closeTo(2 * S2Earth.radiusMeters, 0));
      expect(
          S2Earth.toMetersFromChordAngle(S1ChordAngle.fromDegrees(180)),
          closeTo(S2Earth.radiusMeters * math.pi, chordAngleEpsilon));
    });

    test('testSolidAngleConversion', () {
      expect(
          S2Earth.squareKmToSteradians(math.pow(S2Earth.radiusMeters / 1000, 2).toDouble()),
          closeTo(1, 0));
      expect(
          S2Earth.steradiansToSquareKm(math.pow(0.5, 2).toDouble()),
          closeTo(math.pow(0.5 * S2Earth.radiusKm, 2), 0));
      expect(
          S2Earth.squareMetersToSteradians(math.pow(S2Earth.radiansToKm(0.3) * 1000, 2).toDouble()),
          closeTo(math.pow(0.3, 2), 0));

      // This one test doesn't equal exactly. Allow 1 ULP epsilon.
      final expected = math.pow(2500, 2);
      expect(
          S2Earth.steradiansToSquareMeters(math.pow(S2Earth.kmToRadians(2.5), 2).toDouble()),
          closeTo(expected, 1e-6));
    });

    test('testGetDistance', () {
      final north = S2Point(0, 0, 1);
      final south = S2Point(0, 0, -1);
      final west = S2Point(0, -1, 0);

      expect(S2Earth.getDistanceKmPoints(west, west), closeTo(0, 0));
      expect(
          S2Earth.getDistanceMetersPoints(north, west),
          closeTo((math.pi / 2) * S2Earth.radiusMeters, 0));
      expect(
          S2Earth.getDistanceKmLatLng(S2LatLng.fromRadians(0, 0.6), S2LatLng.fromRadians(0, -0.4)),
          closeTo(S2Earth.radiusKm, 0));

      // This one test doesn't equal exactly. Allow 1 ULP epsilon.
      final expected = 1000 * S2Earth.radiusKm * math.pi / 4;
      expect(
          S2Earth.getDistanceMetersLatLng(
              S2LatLng.fromDegrees(80, 27), S2LatLng.fromDegrees(55, -153)),
          closeTo(expected, 1e-3));
    });

    test('testGetInitialBearing', () {
      final equator0 = S2LatLng.fromDegrees(0, 0);
      final equator50 = S2LatLng.fromDegrees(0, 50);
      final equator100 = S2LatLng.fromDegrees(0, 100);

      // Eastward on Equator.
      expect(
          S2Earth.getInitialBearing(equator50, equator100).degrees,
          closeTo(90, 1e-10));

      // Westward on Equator.
      expect(
          S2Earth.getInitialBearing(equator100, equator0).degrees,
          closeTo(-90, 1e-10));

      // Northward from Meridian.
      expect(
          S2Earth.getInitialBearing(
              S2LatLng.fromDegrees(16, 28), S2LatLng.fromDegrees(81, 28)).degrees,
          closeTo(0, 1e-10));

      // Southward from Meridian.
      expect(
          S2Earth.getInitialBearing(
              S2LatLng.fromDegrees(24, 64), S2LatLng.fromDegrees(-27, 64)).degrees,
          closeTo(180, 1e-10));

      // Towards the north pole.
      expect(
          S2Earth.getInitialBearing(
              S2LatLng.fromDegrees(12, 75), S2LatLng.fromDegrees(90, 50)).degrees,
          closeTo(0.0, 1e-7));

      // Towards the south pole.
      expect(
          S2Earth.getInitialBearing(
              S2LatLng.fromDegrees(-35, 105), S2LatLng.fromDegrees(-90, -120)).degrees,
          closeTo(180.0, 1e-7));

      final spain = S2LatLng.fromDegrees(40.4379332, -3.749576);
      final japan = S2LatLng.fromDegrees(35.6733227, 139.6403486);
      expect(S2Earth.getInitialBearing(spain, japan).degrees, closeTo(29.2, 1e-2));
      expect(S2Earth.getInitialBearing(japan, spain).degrees, closeTo(-27.2, 1e-2));
    });

    test('testRadiusMeters', () {
      expect(S2Earth.radiusMeters, equals(6371010.0));
    });

    test('testRadiusKm', () {
      expect(S2Earth.radiusKm, closeTo(6371.01, 0.01));
    });

    test('testLowestAltitudeMeters', () {
      expect(S2Earth.lowestAltitudeMeters, equals(-10898));
    });

    test('testHighestAltitudeMeters', () {
      expect(S2Earth.highestAltitudeMeters, equals(8846));
    });

    test('testMetersToAngle', () {
      final quarterCircumference = S2Earth.radiusMeters * math.pi / 2;
      final angle = S2Earth.metersToAngle(quarterCircumference);
      expect(angle.degrees, closeTo(90, 1e-10));
    });

    test('testHaversine', () {
      // Haversine of 0 should be 0
      expect(S2Earth.haversine(0), closeTo(0, 1e-15));
      // Haversine of pi should be 1
      expect(S2Earth.haversine(math.pi), closeTo(1, 1e-10));
      // Haversine of pi/2 should be 0.5
      expect(S2Earth.haversine(math.pi / 2), closeTo(0.5, 1e-10));
    });
  });
}

