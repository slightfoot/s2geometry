// Copyright 2022 Google Inc.
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

import 'package:s2geometry/s2geometry.dart';
import 'package:test/test.dart';

void main() {
  /// Asserts that two points are within a given distance of each other.
  void assertPointsWithinDistance(S2Point a, S2Point b, double maxDistance) {
    final distance = a.angle(b);
    expect(distance, lessThanOrEqualTo(maxDistance),
        reason: 'Points $a and $b are $distance apart, expected <= $maxDistance');
  }

  /// Asserts that roundtripping from projecting and unprojecting an S2 point
  /// yields the same value.
  void assertProjectUnproject(Projection projection, R2Vector px, S2Point x) {
    // The arguments are chosen such that projection is exact, but
    // unprojection may not be.
    expect(projection.project(x), equals(px));
    assertPointsWithinDistance(x, projection.unproject(px), 1e-15);
  }

  test('testInterpolateArgumentsAreNotReversed', () {
    expect(
      Projection.interpolate(0.25, R2Vector(1.0, 5.0), R2Vector(3.0, 9.0)),
      equals(R2Vector(1.5, 6)),
    );
  });

  test('testInterpolateExtrapolation', () {
    expect(
      Projection.interpolate(-2, R2Vector(1.0, 0.0), R2Vector(3.0, 0.0)),
      equals(R2Vector(-3.0, 0)),
    );
  });

  test('testWrapDestination', () {
    // Prefer traversing the Antemeridian rather than traversing the Prime Meridian.
    final proj = PlateCarreeProjection(180);
    final easternPoint = R2Vector(170, 0);
    final westernPoint = R2Vector(-170, 0);
    final adjustedWesternPoint = proj.wrapDestination(easternPoint, westernPoint);
    expect(adjustedWesternPoint, equals(R2Vector(190, 0)));
  });

  test('testInterpolateCheckSameLengthAtBothEndpoints', () {
    // Check that interpolation is exact at both endpoints.
    final a = R2Vector(1.234, -5.456e-20);
    final b = R2Vector(2.1234e-20, 7.456);
    expect(Projection.interpolate(0, a, b), equals(a));
    expect(Projection.interpolate(1, a, b), equals(b));
  });

  test('testMercatorUnproject', () {
    final proj = MercatorProjection(180);
    const inf = double.infinity;
    assertProjectUnproject(proj, R2Vector(0, 0), S2Point(1, 0, 0));
    assertProjectUnproject(proj, R2Vector(180, 0), S2Point(-1, 0, 0));
    assertProjectUnproject(proj, R2Vector(90, 0), S2Point(0, 1, 0));
    assertProjectUnproject(proj, R2Vector(-90, 0), S2Point(0, -1, 0));
    assertProjectUnproject(proj, R2Vector(0, inf), S2Point(0, 0, 1));
    assertProjectUnproject(proj, R2Vector(0, -inf), S2Point(0, 0, -1));
    assertProjectUnproject(
        proj, R2Vector(0, 70.25557896783025), S2LatLng.fromRadians(1, 0).toPoint());
  });

  test('testPlateCarreeUnproject', () {
    final proj = PlateCarreeProjection(180);
    assertProjectUnproject(proj, R2Vector(0, 0), S2Point(1, 0, 0));
    assertProjectUnproject(proj, R2Vector(180, 0), S2Point(-1, 0, 0));
    assertProjectUnproject(proj, R2Vector(90, 0), S2Point(0, 1, 0));
    assertProjectUnproject(proj, R2Vector(-90, 0), S2Point(0, -1, 0));
    assertProjectUnproject(proj, R2Vector(0, 90), S2Point(0, 0, 1));
    assertProjectUnproject(proj, R2Vector(0, -90), S2Point(0, 0, -1));
  });
}

