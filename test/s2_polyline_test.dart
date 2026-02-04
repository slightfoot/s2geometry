// Copyright 2006 Google Inc.
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

/// Tests for S2Polyline.
/// Ported from S2PolylineTest.java

import 'dart:math' as math;

import 'package:s2geometry/s2geometry.dart';
import 'package:test/test.dart';

void main() {
  group('S2Polyline', () {
    test('testBasic', () {
      final empty = S2Polyline([]);
      expect(empty.rectBound, equals(S2LatLngRect.empty()));
      final reversedEmpty = empty.reversed();
      expect(empty, equals(reversedEmpty));
    });

    test('testMayIntersect', () {
      final vertices = <S2Point>[
        S2Point(1, -1.1, 0.8).normalize(),
        S2Point(1, -0.8, 1.1).normalize(),
      ];
      final line = S2Polyline(vertices);
      for (int face = 0; face < 6; ++face) {
        final cell = S2Cell.fromFace(face);
        expect(line.mayIntersect(cell), equals((face & 1) == 0));
      }
    });

    test('testInterpolate', () {
      final vertices = <S2Point>[
        S2Point(1, 0, 0),
        S2Point(0, 1, 0),
        S2Point(0, 1, 1).normalize(),
        S2Point(0, 0, 1),
      ];
      final line = S2Polyline(vertices);

      expect(line.interpolate(-0.1), equals(vertices[0]));
      
      // Test at 0.5 (midpoint)
      final midPoint = line.interpolate(0.5);
      expect(S2.approxEquals(midPoint, vertices[1]), isTrue);
      
      // Test at end
      final endPoint = line.interpolate(1.1);
      expect(S2.approxEquals(endPoint, vertices[3]), isTrue);
    });

    test('testEqualsAndHashCode', () {
      final vertices = <S2Point>[
        S2Point(1, 0, 0),
        S2Point(0, 1, 0),
        S2Point(0, 1, 1).normalize(),
        S2Point(0, 0, 1),
      ];

      final line1 = S2Polyline(vertices);
      final line2 = S2Polyline(vertices);

      expect(line1, equals(line2));
      expect(line1.hashCode, equals(line2.hashCode));

      final fewerVertices = vertices.sublist(1);
      final line3 = S2Polyline(fewerVertices);

      expect(line1, isNot(equals(line3)));
    });

    test('testValid', () {
      // A simple normalized line must be valid
      final vertices = <S2Point>[
        S2Point(1, 0, 0),
        S2Point(0, 1, 0),
      ];
      final line = S2Polyline(vertices);
      expect(line.isValid(), isTrue);
    });

    test('testInvalid', () {
      // A non-normalized line must be invalid
      final vertices = <S2Point>[
        S2Point(1, 0, 0),
        S2Point(0, 2, 0),  // Not normalized
      ];
      final line = S2Polyline(vertices);
      expect(line.isValid(), isFalse);

      // Lines with duplicate points must be invalid
      final vertices2 = <S2Point>[
        S2Point(1, 0, 0),
        S2Point(0, 1, 0),
        S2Point(0, 1, 0),  // Duplicate
      ];
      final line2 = S2Polyline(vertices2);
      expect(line2.isValid(), isFalse);
    });

    test('testReversed', () {
      final vertices = <S2Point>[
        S2Point(1, 0, 0),
        S2Point(0, 1, 0),
        S2Point(0, 0, 1),
      ];
      final line = S2Polyline(vertices);
      final reversed = line.reversed();
      
      expect(reversed.numVertices, equals(line.numVertices));
      expect(reversed.vertex(0), equals(line.vertex(2)));
      expect(reversed.vertex(1), equals(line.vertex(1)));
      expect(reversed.vertex(2), equals(line.vertex(0)));
    });

    test('testGetArclengthAngle', () {
      // Quarter of a great circle
      final vertices = <S2Point>[
        S2Point(1, 0, 0),
        S2Point(0, 1, 0),
      ];
      final line = S2Polyline(vertices);
      final angle = line.getArclengthAngle();
      expect((angle.radians - S2.piOver2).abs(), lessThan(1e-15));
    });

    test('testContainsPoint', () {
      // Polylines never contain points
      final vertices = <S2Point>[
        S2Point(1, 0, 0),
        S2Point(0, 1, 0),
      ];
      final line = S2Polyline(vertices);
      expect(line.containsPoint(S2Point(1, 0, 0)), isFalse);
    });

    test('testContainsCell', () {
      // Polylines never contain cells
      final vertices = <S2Point>[
        S2Point(1, 0, 0),
        S2Point(0, 1, 0),
      ];
      final line = S2Polyline(vertices);
      expect(line.containsCell(S2Cell.fromFace(0)), isFalse);
    });

    test('testGetNearestEdgeIndex', () {
      final latLngs = <S2Point>[
        S2LatLng.fromDegrees(0, 0).toPoint(),
        S2LatLng.fromDegrees(0, 1).toPoint(),
        S2LatLng.fromDegrees(0, 2).toPoint(),
        S2LatLng.fromDegrees(1, 2).toPoint(),
      ];
      final line = S2Polyline(latLngs);

      // Point near first edge
      var testPoint = S2LatLng.fromDegrees(0.5, 0.5).toPoint();
      var edgeIndex = line.getNearestEdgeIndex(testPoint);
      expect(edgeIndex, equals(0));

      // Point near last edge
      testPoint = S2LatLng.fromDegrees(2, 2).toPoint();
      edgeIndex = line.getNearestEdgeIndex(testPoint);
      expect(edgeIndex, equals(2));
    });

    test('testProjectToEdge', () {
      final latLngs = <S2Point>[
        S2LatLng.fromDegrees(0, 0).toPoint(),
        S2LatLng.fromDegrees(0, 1).toPoint(),
        S2LatLng.fromDegrees(0, 2).toPoint(),
      ];
      final line = S2Polyline(latLngs);

      // Project point onto first edge
      final testPoint = S2LatLng.fromDegrees(0.5, 0.5).toPoint();
      final projected = line.projectToEdge(testPoint, 0);
      final projectedLatLng = S2LatLng.fromPoint(projected);
      // Should be on the first edge (lat ~0, lng ~0.5)
      expect(projectedLatLng.latDegrees.abs(), lessThan(1e-10));
    });

    test('testProject', () {
      final pointA = S2Point(1, 0, 0);
      final pointB = S2Point(0, 1, 0);
      final pointC = S2Point(0, 0, 1);
      final line = S2Polyline([pointA, pointB, pointC]);

      // Test at a point on the line (the first vertex)
      expect(S2.approxEquals(line.project(pointA), pointA), isTrue);

      // Test at a point off the line - should project to nearest point on line
      final pointOffFromB = S2Point(-0.1, 1, -0.1).normalize();
      expect(S2.approxEquals(line.project(pointOffFromB), pointB), isTrue);
    });

    test('testProjectDegenerateLine', () {
      // Test projecting on a degenerate polyline (single point)
      final pointA = S2Point(1, 0, 0);
      final pointB = S2Point(0, 1, 0);
      final degenerateLine = S2Polyline([pointA]);
      expect(degenerateLine.project(pointB), equals(pointA));
    });

    test('testIntersectsEmptyPolyline', () {
      final line1 = S2Polyline([
        S2LatLng.fromDegrees(1, 1).toPoint(),
        S2LatLng.fromDegrees(4, 4).toPoint(),
      ]);
      final emptyPolyline = S2Polyline([]);
      expect(emptyPolyline.intersects(line1), isFalse);
    });

    test('testIntersectsOnePointPolyline', () {
      final line1 = S2Polyline([
        S2LatLng.fromDegrees(1, 1).toPoint(),
        S2LatLng.fromDegrees(4, 4).toPoint(),
      ]);
      final line2 = S2Polyline([
        S2LatLng.fromDegrees(1, 1).toPoint(),
      ]);
      expect(line1.intersects(line2), isFalse);
    });

    test('testIntersects', () {
      final line1 = S2Polyline([
        S2LatLng.fromDegrees(1, 1).toPoint(),
        S2LatLng.fromDegrees(4, 4).toPoint(),
      ]);
      final smallCrossing = S2Polyline([
        S2LatLng.fromDegrees(1, 2).toPoint(),
        S2LatLng.fromDegrees(2, 1).toPoint(),
      ]);
      final smallNonCrossing = S2Polyline([
        S2LatLng.fromDegrees(1, 2).toPoint(),
        S2LatLng.fromDegrees(2, 3).toPoint(),
      ]);

      expect(line1.intersects(smallCrossing), isTrue);
      expect(line1.intersects(smallNonCrossing), isFalse);
    });

    test('testCopyConstructor', () {
      final vertices = <S2Point>[
        S2Point(1, 0, 0),
        S2Point(0, 1, 0),
      ];
      final original = S2Polyline(vertices);
      final copy = S2Polyline.from(original);

      expect(copy, equals(original));
      expect(copy.numVertices, equals(original.numVertices));
    });

    test('testRectBound', () {
      // Polyline along the equator
      final vertices = <S2Point>[
        S2LatLng.fromDegrees(0, 0).toPoint(),
        S2LatLng.fromDegrees(0, 10).toPoint(),
        S2LatLng.fromDegrees(0, 20).toPoint(),
      ];
      final line = S2Polyline(vertices);
      final bound = line.rectBound;

      // The bound should contain all vertices
      expect(bound.containsPoint(vertices[0]), isTrue);
      expect(bound.containsPoint(vertices[1]), isTrue);
      expect(bound.containsPoint(vertices[2]), isTrue);
    });

    test('testCapBound', () {
      final vertices = <S2Point>[
        S2Point(1, 0, 0),
        S2Point(0, 1, 0),
      ];
      final line = S2Polyline(vertices);
      final cap = line.capBound;

      // The cap should be valid and non-empty
      expect(cap.isEmpty, isFalse);
      // The midpoint of the polyline should be inside the cap
      final midpoint = S2Point(1, 1, 0).normalize();
      expect(cap.containsPoint(midpoint), isTrue);
    });

    test('testToString', () {
      final vertices = <S2Point>[
        S2Point(1, 0, 0),
        S2Point(0, 1, 0),
      ];
      final line = S2Polyline(vertices);
      final str = line.toString();

      expect(str.contains('S2Polyline'), isTrue);
      expect(str.contains('2'), isTrue);  // numVertices
    });

    test('testGetCellUnionBound', () {
      final vertices = <S2Point>[
        S2Point(1, 0, 0),
        S2Point(0, 1, 0),
      ];
      final line = S2Polyline(vertices);
      final results = <S2CellId>[];
      line.getCellUnionBound(results);
      expect(results, isNotEmpty);
    });

    test('testInterpolateEmpty', () {
      final emptyLine = S2Polyline([]);
      expect(() => emptyLine.interpolate(0.5), throwsStateError);
    });

    test('testInterpolateBeyondEnd', () {
      final vertices = <S2Point>[
        S2Point(1, 0, 0),
        S2Point(0, 1, 0),
      ];
      final line = S2Polyline(vertices);
      // fraction > 1 should return last vertex
      final result = line.interpolate(1.5);
      expect(result, equals(vertices[1]));
    });

    test('testGetNearestEdgeIndexEmpty', () {
      final emptyLine = S2Polyline([]);
      expect(() => emptyLine.getNearestEdgeIndex(S2Point(1, 0, 0)), throwsStateError);
    });

    test('testGetNearestEdgeIndexSingleVertex', () {
      final singlePoint = S2Polyline([S2Point(1, 0, 0)]);
      expect(singlePoint.getNearestEdgeIndex(S2Point(0, 1, 0)), equals(0));
    });

    test('testProjectToEdgeEmpty', () {
      final emptyLine = S2Polyline([]);
      expect(() => emptyLine.projectToEdge(S2Point(1, 0, 0), 0), throwsStateError);
    });

    test('testProjectToEdgeSingleVertex', () {
      final singlePoint = S2Polyline([S2Point(1, 0, 0)]);
      expect(singlePoint.projectToEdge(S2Point(0, 1, 0), 0), equals(S2Point(1, 0, 0)));
    });

    test('testProjectEmpty', () {
      final emptyLine = S2Polyline([]);
      expect(() => emptyLine.project(S2Point(1, 0, 0)), throwsStateError);
    });
  });
}

