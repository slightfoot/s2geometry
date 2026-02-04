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
  group('S2EdgeTessellator', () {
    test('testProjectedNoTessellation', () {
      final plateCarree = PlateCarreeProjection(180.0);
      final tessellator = S2EdgeTessellator(plateCarree, S1Angle.degrees(0.01));

      final vertices = <R2Vector>[];
      tessellator.appendProjected(
          S2Point(1, 0, 0), S2Point(0, 1, 0), vertices);
      expect(vertices.length, equals(2));
    });

    test('testUnprojectedNoTessellation', () {
      final plateCarree = PlateCarreeProjection(180.0);
      final tessellator = S2EdgeTessellator(plateCarree, S1Angle.degrees(0.01));

      final vertices = <S2Point>[];
      tessellator.appendUnprojected(
          R2Vector(0, 30), R2Vector(0, 50), vertices);
      expect(vertices.length, equals(2));
    });

    test('testUnprojectedWrapping', () {
      // This tests that a projected edge that crosses the 180 degree meridian
      // goes the "short way" around the sphere.
      final proj = PlateCarreeProjection(180);
      final tess = S2EdgeTessellator(proj, S1Angle.degrees(0.01));
      final vertices = <S2Point>[];
      tess.appendUnprojected(R2Vector(-170, 0), R2Vector(170, 80), vertices);
      for (final v in vertices) {
        expect(S2LatLng.longitude(v).degrees.abs(), greaterThanOrEqualTo(170.0));
      }
    });

    test('testProjectedWrapping', () {
      // This tests that a projected edge that crosses the 180 degree meridian
      // goes the "short way" around the sphere.
      final proj = PlateCarreeProjection(180);
      final tess = S2EdgeTessellator(proj, S1Angle.degrees(0.01));
      final vertices = <R2Vector>[];
      tess.appendProjected(
          S2LatLng.fromDegrees(0, -170).toPoint(),
          S2LatLng.fromDegrees(0, 170).toPoint(),
          vertices);
      for (final v in vertices) {
        expect(v.x, lessThanOrEqualTo(-170.0));
      }
    });

    test('testInfiniteRecursionBug', () {
      final proj = PlateCarreeProjection(180);
      final oneMicron = S1Angle.radians(1e-6 / 6371.0);
      final tess = S2EdgeTessellator(proj, oneMicron);
      final vertices = <R2Vector>[];
      tess.appendProjected(
          S2LatLng.fromDegrees(3, 21).toPoint(),
          S2LatLng.fromDegrees(1, -159).toPoint(),
          vertices);
      expect(vertices.length, equals(36));
    });

    test('testUnprojectedAccuracy', () {
      final proj = MercatorProjection(180);
      final tolerance = S1Angle.degrees(1e-5);
      final pa = R2Vector(0, 0);
      final pb = R2Vector(89.999999, 179);
      
      final tess = S2EdgeTessellator(proj, tolerance);
      final vertices = <S2Point>[];
      tess.appendUnprojected(pa, pb, vertices);
      
      // Should have tessellated the edge
      expect(vertices.length, greaterThan(1));
    });

    test('testProjectedAccuracy', () {
      final proj = PlateCarreeProjection(180);
      final tolerance = S1Angle.e7(1);
      final a = S2LatLng.fromDegrees(-89.999, -170).toPoint();
      final b = S2LatLng.fromDegrees(50, 100).toPoint();
      
      final tess = S2EdgeTessellator(proj, tolerance);
      final vertices = <R2Vector>[];
      tess.appendProjected(a, b, vertices);
      
      // Should have tessellated the edge
      expect(vertices.length, greaterThan(1));
    });

    test('testProjectedAccuracySeattleToNewYork', () {
      final proj = PlateCarreeProjection(180);
      final tolerance = S1Angle.radians(S2Earth.metersToRadians(1));
      final a = S2LatLng.fromDegrees(47.6062, -122.3321).toPoint();
      final b = S2LatLng.fromDegrees(40.7128, -74.0059).toPoint();
      
      final tess = S2EdgeTessellator(proj, tolerance);
      final vertices = <R2Vector>[];
      tess.appendProjected(a, b, vertices);
      
      // Should have tessellated the edge
      expect(vertices.length, greaterThan(1));
    });

    test('testMinTolerance', () {
      expect(S2EdgeTessellator.minTolerance.radians, equals(1e-13));
    });

    test('testUnprojectedWrappingMultipleCrossings', () {
      // Tests an edge chain that crosses the 180 degree meridian multiple times.
      final proj = PlateCarreeProjection(180);
      final tess = S2EdgeTessellator(proj, S1Angle.degrees(0.01));
      final vertices = <S2Point>[];
      for (double lat = 1; lat <= 10; lat += 1.0) {
        tess.appendUnprojected(
            R2Vector(180 - 0.03 * lat, lat),
            R2Vector(-180 + 0.07 * lat, lat),
            vertices);
        tess.appendUnprojected(
            R2Vector(-180 + 0.07 * lat, lat),
            R2Vector(180 - 0.03 * (lat + 1), lat + 1),
            vertices);
      }
      for (final v in vertices) {
        expect(S2LatLng.longitude(v).degrees.abs(), greaterThanOrEqualTo(175.0));
      }
    });
  });
}

