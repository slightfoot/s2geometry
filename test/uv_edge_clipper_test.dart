// Copyright 2024 Google Inc.
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

import 'dart:math' as math;

import 'package:s2geometry/s2geometry.dart';
import 'package:test/test.dart';

/// Test cases for UVEdgeClipper.
void main() {
  // Cell's 0 and 1 share a U boundary (left and right).
  // Cell's 0 and 2 share a V boundary (top and bottom).
  final kCellToken0 = S2Cell(S2CellId.fromToken('89c25c1'));
  final kCellToken1 = S2Cell(S2CellId.fromToken('89c25c3'));
  final kCellToken2 = S2Cell(S2CellId.fromToken('89c25c7'));

  late UVEdgeClipper clipper;
  late math.Random random;

  setUp(() {
    clipper = UVEdgeClipper();
    clipper.initFromCell(kCellToken0);
    random = math.Random(42); // Fixed seed for reproducibility
  });

  S2Point point(double lat, double lng) =>
      S2LatLng.fromDegrees(lat, lng).toPoint();

  R2Edge edge(R2Vector v0, R2Vector v1) {
    final e = R2Edge();
    e.initFromPoints(v0, v1);
    return e;
  }

  R2Vector randPointInBoundary(R2Rect boundary) {
    final u = boundary.x.lo + random.nextDouble() * (boundary.x.hi - boundary.x.lo);
    final v = boundary.y.lo + random.nextDouble() * (boundary.y.hi - boundary.y.lo);
    return R2Vector(u, v);
  }

  S2Point toXyz(int face, R2Vector uv) =>
      S2Projections.faceUvToXyz(face, uv.x, uv.y);

  bool onBoundary(R2Vector a, R2Rect rect) {
    return (a.x == rect.x.lo) ||
        (a.x == rect.x.hi) ||
        (a.y == rect.y.lo) ||
        (a.y == rect.y.hi);
  }

  void checkColinear(R2Vector a, R2Vector b, R2Vector c) {
    final ab = b.sub(a);
    final ac = c.sub(a);
    final det = ab.x * ac.y - ab.y * ac.x;
    // The interpolation to an edge has a max absolute error of 2.25 epsilon,
    // and the determinant above 8 epsilon, which is 2.27e-15, round up a bit.
    expect(det.abs(), lessThan(2.5e-15));
  }

  group('UVEdgeClipper', () {
    test('testAllPermutationsWork', () {
      final testCases = _buildTestCases();
      final raw0 = R2Vector.origin();
      final raw1 = R2Vector.origin();

      for (final testCase in testCases) {
        S2Projections.validFaceXyzToUvInto(kCellToken0.face, testCase.v0, raw0);
        S2Projections.validFaceXyzToUvInto(kCellToken0.face, testCase.v1, raw1);
        final boundary = kCellToken0.boundUV;

        if (clipper.clipEdge(testCase.v0, testCase.v1)) {
          expect(testCase.outcode0 & testCase.outcode1, equals(R2EdgeClipper.inside));

          if (testCase.outcode0 != R2EdgeClipper.inside) {
            expect(clipper.clippedUvEdge.v0, isNot(equals(raw0)));
            expect(onBoundary(clipper.clippedUvEdge.v0, boundary), isTrue);
            expect(clipper.outcode(0), isNot(equals(R2EdgeClipper.inside)));
          } else {
            expect(clipper.clippedUvEdge.v0, equals(raw0));
            expect(clipper.outcode(0), equals(R2EdgeClipper.inside));
          }

          if (testCase.outcode1 != R2EdgeClipper.inside) {
            expect(clipper.clippedUvEdge.v1, isNot(equals(raw1)));
            expect(onBoundary(clipper.clippedUvEdge.v1, boundary), isTrue);
            expect(clipper.outcode(1), isNot(equals(R2EdgeClipper.inside)));
          } else {
            expect(clipper.clippedUvEdge.v1, equals(raw1));
            expect(clipper.outcode(1), equals(R2EdgeClipper.inside));
          }

          // Clipped edges should be co-linear with the original edge.
          checkColinear(raw0, clipper.clippedUvEdge.v0, clipper.clippedUvEdge.v1);
          checkColinear(raw1, clipper.clippedUvEdge.v0, clipper.clippedUvEdge.v1);
        } else {
          // Not clipped, the two vertices must have been in the same exterior region.
          expect(testCase.outcode0 & testCase.outcode1, isNot(equals(R2EdgeClipper.inside)));
          expect(clipper.outcode(0), equals(R2EdgeClipper.outside));
          expect(clipper.outcode(1), equals(R2EdgeClipper.outside));
        }
      }
    });

    test('testSameResultAcrossCellBoundary', () {
      final boundary0 = kCellToken0.boundUV;
      final boundary1 = kCellToken1.boundUV;
      final boundary2 = kCellToken2.boundUV;
      expect(boundary0.y.hi, equals(boundary1.y.lo));
      expect(boundary0.x.hi, equals(boundary2.x.lo));

      final kBoundaryU = boundary0.y.hi;
      final kBoundaryV = boundary0.x.hi;

      for (int i = 0; i < 100; i++) {
        final uv0 = randPointInBoundary(boundary0);
        final uv1 = randPointInBoundary(boundary1);
        final uv2 = randPointInBoundary(boundary2);

        final pnt0 = S2Projections.faceUvToXyz(kCellToken0.face, uv0.x, uv0.y);
        final pnt1 = S2Projections.faceUvToXyz(kCellToken0.face, uv1.x, uv1.y);
        final pnt2 = S2Projections.faceUvToXyz(kCellToken0.face, uv2.x, uv2.y);

        // Test crossing the U boundary for consistency.
        clipper.initFromCell(kCellToken0);
        expect(clipper.clipEdge(pnt0, pnt1), isTrue);
        expect(clipper.clippedUvEdge.v1.y, equals(kBoundaryU));

        clipper.initFromCell(kCellToken1);
        expect(clipper.clipEdge(pnt0, pnt1), isTrue);
        expect(clipper.clippedUvEdge.v0.y, equals(kBoundaryU));

        // Test crossing the V boundary for consistency.
        clipper.initFromCell(kCellToken0);
        expect(clipper.clipEdge(pnt0, pnt2), isTrue);
        expect(clipper.clippedUvEdge.v1.x, equals(kBoundaryV));

        clipper.initFromCell(kCellToken2);
        expect(clipper.clipEdge(pnt0, pnt2), isTrue);
        expect(clipper.clippedUvEdge.v0.x, equals(kBoundaryV));
      }
    });

    test('testClipConnectedEdges', () {
      // A rectangle to sample edge endpoints from.
      final parentRect = S2Cell(kCellToken0.id.parent).boundUV;
      final face = kCellToken0.face;

      // Two clippers, one of which will use the "connected" optimization.
      clipper.initFromCell(kCellToken0);
      final connectedClipper = UVEdgeClipper.fromCell(kCellToken0);

      // Create and clip the initial edge.
      final first = toXyz(face, randPointInBoundary(parentRect));
      var prev = toXyz(face, randPointInBoundary(parentRect));

      expect(clipper.clipEdge(first, prev),
          equals(connectedClipper.clipEdge(first, prev)));
      expect(clipper.clippedUvEdge.isEqualTo(connectedClipper.clippedUvEdge), isTrue);
      expect(clipper.outcode(0), equals(connectedClipper.outcode(0)));
      expect(clipper.outcode(1), equals(connectedClipper.outcode(1)));

      // Repeatedly generate another point and clip the edge.
      for (int i = 0; i < 100; i++) {
        final next = toXyz(face, randPointInBoundary(parentRect));
        expect(clipper.clipEdge(prev, next),
            equals(connectedClipper.clipEdge(prev, next, connected: true)));
        expect(clipper.clippedUvEdge.isEqualTo(connectedClipper.clippedUvEdge), isTrue);
        expect(clipper.outcode(0), equals(connectedClipper.outcode(0)));
        expect(clipper.outcode(1), equals(connectedClipper.outcode(1)));
        prev = next;
      }
    });

    test('testPointsOnBoundaryUnchanged', () {
      final rect = kCellToken0.boundUV;
      final uv0 = R2Vector(rect.x.lo, rect.y.lo);
      final uv1 = R2Vector(rect.x.hi, rect.y.lo);
      final uv2 = R2Vector(rect.x.hi, rect.y.hi);
      final uv3 = R2Vector(rect.x.lo, rect.y.hi);
      final pnt0 = S2Projections.faceUvToXyz(kCellToken0.face, uv0.x, uv0.y);
      final pnt1 = S2Projections.faceUvToXyz(kCellToken0.face, uv1.x, uv1.y);
      final pnt2 = S2Projections.faceUvToXyz(kCellToken0.face, uv2.x, uv2.y);
      final pnt3 = S2Projections.faceUvToXyz(kCellToken0.face, uv3.x, uv3.y);

      clipper.initFromCell(kCellToken0);

      expect(clipper.clipEdge(pnt0, pnt1), isTrue);
      expect(clipper.clippedUvEdge.isEqualTo(edge(uv0, uv1)), isTrue);
      expect(clipper.clippedUvEdge.isEqualTo(clipper.faceUvEdge), isTrue);
      expect(clipper.outcode(0), equals(R2EdgeClipper.inside));
      expect(clipper.outcode(1), equals(R2EdgeClipper.inside));

      expect(clipper.clipEdge(pnt1, pnt2), isTrue);
      expect(clipper.clippedUvEdge.isEqualTo(edge(uv1, uv2)), isTrue);
      expect(clipper.clippedUvEdge.isEqualTo(clipper.faceUvEdge), isTrue);
      expect(clipper.outcode(0), equals(R2EdgeClipper.inside));
      expect(clipper.outcode(1), equals(R2EdgeClipper.inside));

      expect(clipper.clipEdge(pnt2, pnt3), isTrue);
      expect(clipper.clippedUvEdge.isEqualTo(edge(uv2, uv3)), isTrue);
      expect(clipper.clippedUvEdge.isEqualTo(clipper.faceUvEdge), isTrue);
      expect(clipper.outcode(0), equals(R2EdgeClipper.inside));
      expect(clipper.outcode(1), equals(R2EdgeClipper.inside));

      expect(clipper.clipEdge(pnt3, pnt0), isTrue);
      expect(clipper.clippedUvEdge.isEqualTo(edge(uv3, uv0)), isTrue);
      expect(clipper.clippedUvEdge.isEqualTo(clipper.faceUvEdge), isTrue);
      expect(clipper.outcode(0), equals(R2EdgeClipper.inside));
      expect(clipper.outcode(1), equals(R2EdgeClipper.inside));
    });

    test('testLineOnBoundaryClipped', () {
      final kFace = kCellToken0.face;
      final rect = kCellToken0.boundUV;
      final uv0 = R2Vector(rect.x.lo, rect.y.lo);
      final uv1 = R2Vector(rect.x.hi, rect.y.lo);
      final miduv0 = uv0.add(uv1.sub(uv0).mul(1.0 / 3));
      final miduv1 = uv0.add(uv1.sub(uv0).mul(2.0 / 3));
      final pnt0 = S2Projections.faceUvToXyz(kFace, uv0.x, uv0.y);
      final pnt1 = S2Projections.faceUvToXyz(kFace, uv1.x, uv1.y);
      final midpnt0 = S2Projections.faceUvToXyz(kFace, miduv0.x, miduv0.y);
      final midpnt1 = S2Projections.faceUvToXyz(kFace, miduv1.x, miduv1.y);

      final hi = pnt0.add(pnt1.sub(pnt0).mul(2));
      final lo = pnt0.sub(pnt1.sub(pnt0).mul(2));

      // Segment extends past vertex 1.
      expect(clipper.clipEdge(pnt0, hi), isTrue);
      expect(clipper.clippedUvEdge.isEqualTo(edge(uv0, uv1)), isTrue);

      // Segment extends past vertex 0.
      expect(clipper.clipEdge(lo, pnt1), isTrue);
      expect(clipper.clippedUvEdge.isEqualTo(edge(uv0, uv1)), isTrue);

      // Segment extends past both.
      expect(clipper.clipEdge(lo, hi), isTrue);
      expect(clipper.clippedUvEdge.isEqualTo(edge(uv0, uv1)), isTrue);

      // Point in the middle of the boundary to vertex 1.
      expect(clipper.clipEdge(midpnt0, pnt1), isTrue);
      expect(clipper.clippedUvEdge.isEqualTo(edge(miduv0, uv1)), isTrue);

      // Vertex 0 to point in the middle of the boundary.
      expect(clipper.clipEdge(pnt0, midpnt0), isTrue);
      expect(clipper.clippedUvEdge.isEqualTo(edge(uv0, miduv0)), isTrue);

      // Two points inside the boundary segment.
      expect(clipper.clipEdge(midpnt0, midpnt1), isTrue);
      expect(clipper.clippedUvEdge.isEqualTo(edge(miduv0, miduv1)), isTrue);
    });

    test('testOutsideBetweenDifferentRegionsClipped', () {
      // Each of these lines goes from an exterior region of the cell to a
      // different one, without touching the cell itself.
      final edges = [
        [point(40.708180, -73.937992), point(40.710042, -73.934527)],
        [point(40.707250, -73.914758), point(40.703740, -73.909094)],
        [point(40.686950, -73.909737), point(40.684151, -73.915059)],
        [point(40.691128, -73.939047), point(40.687125, -73.933897)],
        [point(40.671643, -73.924799), point(40.741652, -73.976984)],
      ];
      for (final e in edges) {
        expect(clipper.clipEdge(e[0], e[1]), isFalse);
        expect(clipper.outcode(0), equals(R2EdgeClipper.outside));
        expect(clipper.outcode(1), equals(R2EdgeClipper.outside));
      }
    });

    test('testEdgeHitAcrossFacesWorks', () {
      final v0 = S2LatLng.fromDegrees(-1.801, -68.044).toPoint();
      final v1 = S2LatLng.fromDegrees(8.0160, 82.425).toPoint();
      clipper.initFromCell(S2Cell(S2CellId.fromToken('11')));
      expect(clipper.clipEdge(v0, v1), isTrue);
    });

    test('testEdgeMissedFaceDetected0', () {
      final edge0 = [point(29, -15), point(-2, -97)];
      final edge1 = [point(-2, -97), point(-10, -173)];

      clipper.initFromCell(S2Cell(S2CellId.fromToken('11')));
      expect(clipper.clipEdge(edge0[0], edge0[1]), isFalse);
      expect(clipper.clipEdge(edge1[0], edge1[1]), isFalse);
      expect(clipper.missedFace, isTrue);
    });

    test('testEdgeMissedFaceDetected1', () {
      final edge0 = [point(29, -15), point(-2, -97)];
      final edge1 = [point(-2, -97), point(-10, -110)];
      clipper.initFromCell(S2Cell(S2CellId.fromToken('11')));
      expect(clipper.clipEdge(edge0[0], edge0[1]), isFalse);
      expect(clipper.clipEdge(edge1[0], edge1[1]), isFalse);
      expect(clipper.missedFace, isTrue);
    });

    test('testEdgeMissedFaceDetected2', () {
      clipper.initFromCell(S2Cell(S2CellId.fromToken('11')));
      final e = [point(-2, -97), point(-10, -110)];
      expect(clipper.clipEdge(e[0], e[1]), isFalse);
      expect(clipper.missedFace, isTrue);
    });

    test('testAlmostMissesFace', () {
      // The cell is on face 4 and the edge is on face 2 but touches face 4.
      final testClipper = UVEdgeClipper();
      testClipper.initFromCell(S2Cell(S2CellId.fromToken('800c')));
      final kEdge = [
        S2Point(-0.535533175298229, -0.597161710994181, 0.597161710994181),
        S2Point(-0.528388331336849, -0.589982219252971, 0.610513515225011),
      ];
      expect(testClipper.clipEdge(kEdge[0], kEdge[1]), isTrue);
      expect(testClipper.clippedUvEdge.v0.x, equals(-1.0));
      expect(testClipper.clippedUvEdge.v1.x, equals(-1.0));
    });

    test('testFaceAndBoundarySetFromCell', () {
      final kCell = S2Cell(S2CellId.fromToken('800c'));
      final testClipper = UVEdgeClipper();
      testClipper.initFromCell(kCell);
      expect(testClipper.clipFace, equals(4));
      expect(testClipper.clipRect, equals(kCell.boundUV));
    });

    test('testBouncesOffFace', () {
      clipper.initFromCell(S2Cell(S2CellId.fromToken('81c')));
      final cell = S2Cell(S2CellId.fromToken('7f4'));

      final a = cell.getVertex(1);
      final b = cell.getVertex(2);
      final c = cell.getVertex(0);
      expect(clipper.clipEdge(a, b), isTrue);
      expect(clipper.outcode(0), equals(R2EdgeClipper.bottom));
      expect(clipper.clippedUvEdge.v0.y, equals(-1.0));
      expect(clipper.clippedUvEdge.v1.y, equals(-1.0));

      expect(clipper.clipEdge(b, c), isTrue);
      expect(clipper.outcode(1), equals(R2EdgeClipper.bottom));
      expect(clipper.clippedUvEdge.v0.y, equals(-1.0));
      expect(clipper.clippedUvEdge.v1.y, equals(-1.0));
    });
  });
}

/// A 1D test point with an outcode and value.
class _TestPoint1D {
  final int code;
  final double val;

  _TestPoint1D(this.code, this.val);
}

/// A 2D test point with combined outcodes.
class _TestPoint2D {
  final int code;
  final S2Point point;

  _TestPoint2D(this.code, this.point);
}

/// A test case for edge clipping.
class _EdgeClipperTestCase {
  final S2Point v0;
  final S2Point v1;
  final int outcode0;
  final int outcode1;

  _EdgeClipperTestCase(this.v0, this.outcode0, this.v1, this.outcode1);
}

/// Builds all 81 combinations of test points.
List<_EdgeClipperTestCase> _buildTestCases() {
  final latTestPoints = [
    _TestPoint1D(R2EdgeClipper.top, 40.715),
    _TestPoint1D(R2EdgeClipper.inside, 40.700),
    _TestPoint1D(R2EdgeClipper.bottom, 40.685),
  ];
  final lonTestPoints = [
    _TestPoint1D(R2EdgeClipper.left, -73.940),
    _TestPoint1D(R2EdgeClipper.inside, -73.925),
    _TestPoint1D(R2EdgeClipper.right, -73.910),
  ];

  // Build all 9 combinations of coordinates to form 2D test points
  final points = <_TestPoint2D>[];
  for (int i = 0; i < 3; i++) {
    final latPnt = latTestPoints[i];
    for (int j = 0; j < 3; j++) {
      final lonPnt = lonTestPoints[j];
      points.add(_TestPoint2D(
        latPnt.code | lonPnt.code,
        S2LatLng.fromDegrees(latPnt.val, lonPnt.val).toPoint(),
      ));
    }
  }

  // Build all 81 combinations of endpoints.
  final testCases = <_EdgeClipperTestCase>[];
  for (int i = 0; i < 9; i++) {
    final v0 = points[i];
    for (int j = 0; j < 9; j++) {
      final v1 = points[j];
      testCases.add(_EdgeClipperTestCase(v0.point, v0.code, v1.point, v1.code));
    }
  }
  return testCases;
}

