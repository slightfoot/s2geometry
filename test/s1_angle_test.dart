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

/// Tests for S1Angle.
/// Ported from S1AngleTest.java
library;

import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:s2geometry/s2geometry.dart';

import 'geometry_test_case.dart';

void main() {
  group('S1Angle', () {
    test('testBasic', () {
      // Check that the conversion between Pi radians and 180 degrees is exact.
      assertExactly(math.pi, S1Angle.radians(math.pi).radians);
      assertExactly(180.0, S1Angle.radians(math.pi).degrees);
      assertExactly(math.pi, S1Angle.degrees(180).radians);
      assertExactly(180.0, S1Angle.degrees(180).degrees);

      assertExactly(90.0, S1Angle.radians(math.pi / 2).degrees);

      // Check negative angles.
      assertExactly(-90.0, S1Angle.radians(-math.pi / 2).degrees);
      assertExactly(-math.pi / 4, S1Angle.degrees(-45).radians);

      // Check that E5/E6/E7 representations work as expected.
      expect(S1Angle.e5(2000000), equals(S1Angle.degrees(20)));
      expect(S1Angle.e6(-60000000), equals(S1Angle.degrees(-60)));
      expect(S1Angle.e7(750000000), equals(S1Angle.degrees(75)));
      expect(S1Angle.e5(2000000), equals(S1Angle.degrees(20)));
      expect(S1Angle.e6(-60000000), equals(S1Angle.degrees(-60)));
      expect(S1Angle.e7(750000000), equals(S1Angle.degrees(75)));
      expect(S1Angle.degrees(12.34567).e5, equals(1234567));
      expect(S1Angle.degrees(12.345678).e6, equals(12345678));
      expect(S1Angle.degrees(-12.3456789).e7, equals(-123456789));
    });

    test('testMath', () {
      // 29.999999999999996
      assertAlmostEquals(30.0, S1Angle.degrees(10).add(S1Angle.degrees(20)).degrees);
      assertExactly(-10, S1Angle.degrees(10).sub(S1Angle.degrees(20)).degrees);
      assertExactly(20, S1Angle.degrees(10).mul(2.0).degrees);
      assertExactly(5, S1Angle.degrees(10).div(2.0).degrees);
      assertExactly(1.0, S1Angle.degrees(0).cos);
      assertExactly(1.0, S1Angle.degrees(90).sin);
      assertAlmostEquals(1.0, S1Angle.degrees(45).tan); // 0.9999999999999999
    });

    test('testDistance', () {
      // Check distance accessor for arbitrary sphere
      assertExactly(100.0 * math.pi, S1Angle.radians(math.pi).distance(100.0));
      assertExactly(50.0 * math.pi, S1Angle.radians(math.pi / 2).distance(100.0));
      assertExactly(25.0 * math.pi, S1Angle.radians(math.pi / 4).distance(100.0));
    });

    test('testE7Overflow', () {
      // Normalized angles should never overflow.
      expect(S1Angle.degrees(-180.0).e7, equals(-1800000000));
      expect(S1Angle.degrees(180.0).e7, equals(1800000000));

      // Overflow starts at 214.7483648 degrees.
      expect(() => S1Angle.degrees(215).e7, throwsArgumentError);
      expect(() => S1Angle.degrees(-215).e7, throwsArgumentError);
    });

    test('testNormalize', () {
      assertExactly(0.0, S1Angle.degrees(360.0).normalize().degrees);
      assertExactly(-90.0, S1Angle.degrees(-90.0).normalize().degrees);
      assertExactly(180.0, S1Angle.degrees(-180.0).normalize().degrees);
      assertExactly(90.0, S1Angle.degrees(90.0).normalize().degrees);
      assertExactly(180.0, S1Angle.degrees(180.0).normalize().degrees);
      assertExactly(-90.0, S1Angle.degrees(270.0).normalize().degrees);
      assertExactly(180.0, S1Angle.degrees(540.0).normalize().degrees);
      assertExactly(90.0, S1Angle.degrees(-270.0).normalize().degrees);

      // PI is unchanged.
      assertExactly(math.pi, S1Angle.radians(math.pi).normalize().radians);

      // nextAfter PI should wrap around to _exactly_ nextAfter -Pi.
      assertExactly(
        Platform.nextAfter(-math.pi, 0.0),
        S1Angle.radians(Platform.nextAfter(math.pi, 4.0)).normalize().radians,
      );

      // -PI is wrapped around to _exactly_ PI.
      assertExactly(math.pi, S1Angle.radians(-math.pi).normalize().radians);

      // nextAfter (downwards) -PI should wrap around to _exactly_ nextAfter (downwards) PI.
      assertExactly(
        Platform.nextAfter(math.pi, 0.0),
        S1Angle.radians(Platform.nextAfter(-math.pi, -4.0)).normalize().radians,
      );
    });

    test('testAlreadyNormalizedIsIdentity', () {
      final angle = S1Angle.degrees(90.0);
      expect(identical(angle.normalize(), angle), isTrue);
    });

    test('testInfinity', () {
      expect(S1Angle.radians(1e30).compareTo(S1Angle.infinity) < 0, isTrue);
      expect(S1Angle.infinity.neg().compareTo(S1Angle.zero) < 0, isTrue);
      expect(S1Angle.infinity == S1Angle.infinity, isTrue);
    });

    test('testBuilder_zero', () {
      expect(S1AngleBuilder().build(), equals(S1Angle.zero));
    });

    test('testBuilder_radians', () {
      assertExactly(
        1.5,
        S1AngleBuilder().add(0.5).add(0.75).add(0.25).build().radians,
      );
    });

    test('testBuilder_angles', () {
      final angle = S1AngleBuilder()
          .add(S1Angle.degrees(90))
          .add(S1Angle.degrees(45))
          .add(S1Angle.degrees(30))
          .add(S1Angle.degrees(15))
          .build();
      assertExactly(180.0, angle.degrees);
    });

    test('testBuilder_mixed', () {
      final builder = S1AngleBuilder();
      builder.add(math.pi / 2);
      builder.add(S1Angle.degrees(45));
      final angle1 = builder.build();
      assertExactly(0.75 * math.pi, angle1.radians);
      // Add more to the builder, make sure it didn't mutate the already-built value
      builder.add(math.pi);
      final angle2 = builder.build();
      assertExactly(1.75 * math.pi, angle2.radians);
      assertExactly(0.75 * math.pi, angle1.radians);
    });

    test('testToBuilder', () {
      final base = S1Angle.radians(math.pi);
      final builder = base.toBuilder();
      builder.add(S1Angle.degrees(90));
      assertExactly(1.5 * math.pi, builder.build().radians);
      assertExactly(math.pi, base.radians); // Builder uses a copy, not original
    });

    // Note: Java serialization test is not applicable to Dart
  });
}

