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

/// Tests for S2Cell.
/// Ported from S2CellTest.java
library;

import 'package:test/test.dart';
import 'package:s2geometry/s2geometry.dart';

import 'geometry_test_case.dart';

void main() {
  group('S2Cell', () {
    test('testFaces', () {
      final edges = <S2Point>[];
      final vertices = <S2Point>[];

      for (int face = 0; face < 6; ++face) {
        final id = S2CellId.fromFacePosLevel(face, 0, 0);
        final cell = S2Cell(id);
        expect(cell.id, equals(id));
        expect(cell.face, equals(face));
        expect(cell.level, equals(0));
        // Top-level faces have alternating orientations to get RHS coordinates.
        expect(cell.orientation, equals(face & S2.swapMask));
        expect(cell.isLeaf, isFalse);

        for (int k = 0; k < 4; ++k) {
          // Collect edges and vertices for counting
          edges.add(cell.getEdgeRaw(k));
          vertices.add(cell.getVertexRaw(k));

          // Edges should be perpendicular to their bounding vertices
          assertAlmostEquals(cell.getVertexRaw(k).dotProd(cell.getEdgeRaw(k)), 0.0);
          assertAlmostEquals(cell.getVertexRaw(k + 1).dotProd(cell.getEdgeRaw(k)), 0.0);

          // Check that cross product of vertices is aligned with edge
          assertAlmostEquals(
              cell
                  .getVertexRaw(k)
                  .crossProd(cell.getVertexRaw(k + 1))
                  .normalize()
                  .dotProd(cell.getEdge(k)),
              1.0);
        }
      }

      // Count edges - each unique edge should appear exactly twice
      // We need to check with a tolerance for floating point comparison
      int edgesWithMultiplicity2 = 0;
      for (int i = 0; i < edges.length; i++) {
        int count = 0;
        for (int j = 0; j < edges.length; j++) {
          if ((edges[i] - edges[j]).norm < 1e-10) {
            count++;
          }
        }
        if (count == 2) edgesWithMultiplicity2++;
      }
      expect(edgesWithMultiplicity2, equals(edges.length));

      // Count vertices - each unique vertex should appear exactly three times
      int verticesWithMultiplicity3 = 0;
      for (int i = 0; i < vertices.length; i++) {
        int count = 0;
        for (int j = 0; j < vertices.length; j++) {
          if ((vertices[i] - vertices[j]).norm < 1e-10) {
            count++;
          }
        }
        if (count == 3) verticesWithMultiplicity3++;
      }
      expect(verticesWithMultiplicity3, equals(vertices.length));
    });

    test('testContainment', () {
      final face0 = S2Cell.fromFace(0);
      final children = face0.subdivide();
      final child0 = children[0];
      final child1 = children[1];
      final grandChildren = child0.subdivide();

      // Parent contains children
      expect(face0.containsCell(child0), isTrue);
      expect(face0.containsCell(child1), isTrue);
      expect(face0.containsCell(grandChildren[0]), isTrue);

      // Children do not contain parent
      expect(child0.containsCell(face0), isFalse);
      expect(grandChildren[0].containsCell(face0), isFalse);

      // Siblings do not contain each other
      expect(child0.containsCell(child1), isFalse);
      expect(child1.containsCell(child0), isFalse);

      // mayIntersect tests
      expect(face0.mayIntersect(child0), isTrue);
      expect(child0.mayIntersect(face0), isTrue);
      expect(child0.mayIntersect(child1), isFalse);
    });

    test('testSubdivide', () {
      for (int face = 0; face < 6; ++face) {
        final cell = S2Cell.fromFace(face);
        final children = cell.subdivide();

        expect(children.length, equals(4));

        var childId = cell.id.childBegin;
        for (int i = 0; i < 4; ++i) {
          expect(children[i].id, equals(childId));
          expect(children[i].face, equals(face));
          expect(children[i].level, equals(1));
          childId = childId.next;
        }
      }
    });

    test('testCapBound', () {
      for (int face = 0; face < 6; ++face) {
        final cell = S2Cell.fromFace(face);
        final cap = cell.capBound;

        // The cap should contain all vertices
        for (int k = 0; k < 4; ++k) {
          expect(cap.containsPoint(cell.getVertex(k)), isTrue);
        }

        // The cap should contain the center
        expect(cap.containsPoint(cell.center), isTrue);
      }
    });

    test('testRectBound', () {
      for (int face = 0; face < 6; ++face) {
        final cell = S2Cell.fromFace(face);
        final rect = cell.rectBound;

        // The rect should contain the center
        expect(rect.containsPoint(cell.centerRaw), isTrue);
      }
    });

    test('testAreas', () {
      // The area of a face cell should be approximately 4*pi/6
      final faceCell = S2Cell.fromFace(0);
      final expectedFaceArea = 4 * S2.pi / 6;

      // Allow for some numerical error
      expect((faceCell.exactArea - expectedFaceArea).abs() < 1e-10, isTrue);
      expect((faceCell.approxArea - expectedFaceArea).abs() < 0.1, isTrue);
      expect((faceCell.averageArea - expectedFaceArea).abs() < 1e-10, isTrue);
    });

    test('testContainsPoint', () {
      final cell = S2Cell.fromPoint(S2LatLng.fromDegrees(0, 0).toPoint());
      final center = cell.center;

      // Cell should contain its own center
      expect(cell.containsPoint(center), isTrue);
    });

    test('testFromPoint', () {
      final point = S2LatLng.fromDegrees(45, 60).toPoint();
      final cell = S2Cell.fromPoint(point);
      expect(cell.containsPoint(point), isTrue);
      expect(cell.isLeaf, isTrue);
    });

    test('testFromLatLng', () {
      final ll = S2LatLng.fromDegrees(45, 60);
      final cell = S2Cell.fromLatLng(ll);
      expect(cell.containsPoint(ll.toPoint()), isTrue);
      expect(cell.isLeaf, isTrue);
    });

    test('testCenterRaw', () {
      final cell = S2Cell.fromFace(0);
      final centerRaw = cell.centerRaw;
      expect(centerRaw.norm, greaterThan(0));
      // The normalized center should be the same as center
      expect((centerRaw.normalize() - cell.center).norm, lessThan(1e-10));
    });

    test('testCenterUV', () {
      final cell = S2Cell.fromFace(0);
      final centerUV = cell.centerUV;
      expect(centerUV.x, closeTo(0, 1e-10));
      expect(centerUV.y, closeTo(0, 1e-10));
    });

    test('testBoundUV', () {
      final cell = S2Cell.fromFace(0);
      final boundUV = cell.boundUV;
      expect(boundUV.x.lo, lessThan(0));
      expect(boundUV.x.hi, greaterThan(0));
      expect(boundUV.y.lo, lessThan(0));
      expect(boundUV.y.hi, greaterThan(0));
    });

    test('testSizeIJ', () {
      // Face cell has max size
      final faceCell = S2Cell.fromFace(0);
      expect(faceCell.sizeIJ, greaterThan(0));

      // Smaller level has smaller size
      final children = faceCell.subdivide();
      expect(children[0].sizeIJ, lessThan(faceCell.sizeIJ));
    });

    test('testGetEdge', () {
      final cell = S2Cell.fromFace(0);
      for (int k = 0; k < 4; k++) {
        final edge = cell.getEdge(k);
        expect(edge.norm, closeTo(1.0, 1e-10));
      }
    });

    test('testGetVertex', () {
      final cell = S2Cell.fromFace(0);
      for (int k = 0; k < 4; k++) {
        final vertex = cell.getVertex(k);
        expect(vertex.norm, closeTo(1.0, 1e-10));
      }
    });

    test('testGetCellUnionBound', () {
      final cell = S2Cell.fromFace(0);
      final cells = <S2CellId>[];
      cell.getCellUnionBound(cells);
      expect(cells.length, equals(1));
      expect(cells[0], equals(cell.id));
    });

    test('testLevel', () {
      final faceCell = S2Cell.fromFace(0);
      expect(faceCell.level, equals(0));

      final children = faceCell.subdivide();
      expect(children[0].level, equals(1));
    });

    test('testOrientation', () {
      for (int face = 0; face < 6; face++) {
        final cell = S2Cell.fromFace(face);
        expect(cell.orientation, isNonNegative);
        expect(cell.orientation, lessThan(4));
      }
    });

    test('testApproxAreaSmallCell', () {
      // Get a small cell at level 10
      final cellId = S2CellId.fromFace(0).childBeginAtLevel(10);
      final cell = S2Cell(cellId);
      expect(cell.approxArea, greaterThan(0));
      expect(cell.approxArea, lessThan(cell.averageArea * 2));
    });

    test('testContainsPointOutsideFace', () {
      // Create a cell on face 0 and test with a point on face 3
      final cell = S2Cell.fromFace(0);
      final pointOnFace3 = S2Point.xNeg;
      expect(cell.containsPoint(pointOnFace3), isFalse);
    });

    test('testEquality', () {
      final cell1 = S2Cell.fromFace(0);
      final cell2 = S2Cell.fromFace(0);
      expect(cell1, equals(cell2));

      final cell3 = S2Cell.fromFace(1);
      expect(cell1 == cell3, isFalse);

      expect(cell1 == "not a cell", isFalse);
    });

    test('testHashCode', () {
      final cell1 = S2Cell.fromFace(0);
      final cell2 = S2Cell.fromFace(0);
      expect(cell1.hashCode, equals(cell2.hashCode));
    });

    test('testToString', () {
      final cell = S2Cell.fromFace(0);
      final str = cell.toString();
      expect(str, contains('0'));
    });

    test('testRectBoundForNonFaceCell', () {
      // Test rectBound for a cell at level > 0
      final cellId = S2CellId.fromFace(0).child(0);
      final cell = S2Cell(cellId);
      final rect = cell.rectBound;
      expect(rect.isEmpty, isFalse);
    });
  });
}
