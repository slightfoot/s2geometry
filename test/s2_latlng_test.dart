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

/// Tests for S2LatLng.
/// Ported from S2LatLngTest.java
library;

import 'dart:math' as math;
import 'package:test/test.dart';
import 'package:s2geometry/s2geometry.dart';

import 'geometry_test_case.dart';

const double M_PI_2 = math.pi / 2;
const double M_PI_4 = math.pi / 4;

void main() {
  group('S2LatLng', () {
    test('testBasic', () {
      final llRad = S2LatLng.fromRadians(M_PI_4, M_PI_2);
      expect(llRad.lat.radians == M_PI_4, isTrue);
      expect(llRad.lng.radians == M_PI_2, isTrue);
      expect(llRad.isValid, isTrue);
      final llDeg = S2LatLng.fromDegrees(45, 90);
      expect(llDeg, equals(llRad));
      expect(llDeg.isValid, isTrue);
      expect(S2LatLng.fromDegrees(-91, 0).isValid, isFalse);
      expect(S2LatLng.fromDegrees(0, 181).isValid, isFalse);

      var bad = S2LatLng.fromDegrees(120, 200);
      expect(bad.isValid, isFalse);
      var better = bad.normalized;
      expect(better.isValid, isTrue);
      expect(better.lat, equals(S1Angle.degrees(90)));
      assertAlmostEquals(better.lng.radians, S1Angle.degrees(-160).radians);

      bad = S2LatLng.fromDegrees(-100, -360);
      expect(bad.isValid, isFalse);
      better = bad.normalized;
      expect(better.isValid, isTrue);
      expect(better.lat, equals(S1Angle.degrees(-90)));
      assertAlmostEquals(better.lng.radians, 0);

      expect(
          S2LatLng.fromDegrees(10, 20)
              .add(S2LatLng.fromDegrees(20, 30))
              .approxEquals(S2LatLng.fromDegrees(30, 50)),
          isTrue);
      expect(
          S2LatLng.fromDegrees(10, 20)
              .sub(S2LatLng.fromDegrees(20, 30))
              .approxEquals(S2LatLng.fromDegrees(-10, -10)),
          isTrue);
      expect(
          S2LatLng.fromDegrees(10, 20)
              .mul(0.5)
              .approxEquals(S2LatLng.fromDegrees(5, 10)),
          isTrue);
    });

    test('testConversion', () {
      // Test special cases: poles, "date line"
      assertAlmostEquals(
          S2LatLng.point(S2LatLng.fromDegrees(90.0, 65.0).toPoint())
              .lat
              .degrees,
          90.0);
      assertExactly(
          -M_PI_2,
          S2LatLng.point(S2LatLng.fromRadians(-M_PI_2, 1).toPoint())
              .lat
              .radians);
      assertAlmostEquals(
          S2LatLng.point(S2LatLng.fromDegrees(12.2, 180.0).toPoint())
              .lng
              .degrees
              .abs(),
          180.0);
      assertExactly(
          math.pi,
          S2LatLng.point(S2LatLng.fromRadians(0.1, -math.pi).toPoint())
              .lng
              .radians
              .abs());

      // Test generation from E5
      final test = S2LatLng.fromE5(123456, 98765);
      assertAlmostEquals(test.lat.degrees, 1.23456);
      assertAlmostEquals(test.lng.degrees, 0.98765);
    });

    test('testNegativeZeros', () {
      // Equal and same sign
      assertIdentical(S2LatLng.latitude(S2Point(1.0, 0.0, -0.0)).radians, 0.0);
      assertIdentical(S2LatLng.longitude(S2Point(1.0, -0.0, 0.0)).radians, 0.0);
      assertIdentical(
          S2LatLng.longitude(S2Point(-1.0, -0.0, 0.0)).radians, math.pi);
      assertIdentical(S2LatLng.longitude(S2Point(-0.0, 0.0, 1.0)).radians, 0.0);
      assertIdentical(
          S2LatLng.longitude(S2Point(-0.0, -0.0, 1.0)).radians, 0.0);
    });

    test('testDistance', () {
      assertExactly(0.0,
          S2LatLng.fromDegrees(90, 0).getDistance(S2LatLng.fromDegrees(90, 0)).radians);
      assertDoubleNear(
          S2LatLng.fromDegrees(-37, 25)
              .getDistance(S2LatLng.fromDegrees(-66, -155))
              .degrees,
          77,
          1e-13);
      assertDoubleNear(
          S2LatLng.fromDegrees(0, 165)
              .getDistance(S2LatLng.fromDegrees(0, -80))
              .degrees,
          115,
          1e-13);
      assertDoubleNear(
          S2LatLng.fromDegrees(47, -127)
              .getDistance(S2LatLng.fromDegrees(-47, 53))
              .degrees,
          180,
          2e-6);
    });
  });
}

