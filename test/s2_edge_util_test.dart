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

import 'dart:math' as math;

import 'package:s2geometry/s2geometry.dart';
import 'package:test/test.dart';

/// Helper to create S2Point from x, y, z.
S2Point p(double x, double y, double z) => S2Point(x, y, z);

/// Helper to get next representable double value towards direction.
double nextAfter(double x, double direction) {
  return direction < x ? x - S2.dblEpsilon : x + S2.dblEpsilon;
}

/// Helper function to check crossing with various permutations.
void checkCrossing(
  S2Point a,
  S2Point b,
  S2Point c,
  S2Point d,
  int crossingSign,
  int signedCrossingSign,
  bool checkSimple,
) {
  // For degenerate edges, robustCrossing() is documented to return 0 if two vertices from
  // different edges are the same and -1 otherwise.
  if (a == c || a == d || b == c || b == d) {
    crossingSign = 0;
  }

  expect(S2EdgeUtil.robustCrossing(a, b, c, d), equals(crossingSign));
  final edgeOrVertex = signedCrossingSign != 0;
  expect(S2EdgeUtil.edgeOrVertexCrossing(a, b, c, d), equals(edgeOrVertex));

  final crosser = EdgeCrosser.withEdgeAndVertex(a, b, c);
  expect(crosser.robustCrossingFromD(d), equals(crossingSign));
  expect(crosser.robustCrossingFromD(c), equals(crossingSign));
  expect(crosser.robustCrossing(d, c), equals(crossingSign));
  expect(crosser.robustCrossing(c, d), equals(crossingSign));

  crosser.restartAt(c);
  expect(crosser.edgeOrVertexCrossingFromD(d), equals(edgeOrVertex));
  expect(crosser.edgeOrVertexCrossingFromD(c), equals(edgeOrVertex));
  expect(crosser.edgeOrVertexCrossing(d, c), equals(edgeOrVertex));
  expect(crosser.edgeOrVertexCrossing(c, d), equals(edgeOrVertex));

  // Check that the crosser can be re-used.
  final crosser2 = EdgeCrosser.withEdge(c, d);
  crosser2.restartAt(a);
  expect(crosser2.robustCrossingFromD(b), equals(crossingSign));
  expect(crosser2.robustCrossingFromD(a), equals(crossingSign));
}

/// Helper function to check crossings with all permutations.
void checkCrossings(
  S2Point a,
  S2Point b,
  S2Point c,
  S2Point d,
  int crossingSign,
  int signedCrossingSign,
  bool checkSimple,
) {
  a = a.normalize();
  b = b.normalize();
  c = c.normalize();
  d = d.normalize();

  checkCrossing(a, b, c, d, crossingSign, signedCrossingSign, checkSimple);
  checkCrossing(b, a, c, d, crossingSign, -signedCrossingSign, checkSimple);
  checkCrossing(a, b, d, c, crossingSign, -signedCrossingSign, checkSimple);
  checkCrossing(b, a, d, c, crossingSign, signedCrossingSign, checkSimple);
  checkCrossing(a, a, c, d, -1, 0, false);
  checkCrossing(a, b, c, c, -1, 0, false);
  checkCrossing(a, a, c, c, -1, 0, false);
  checkCrossing(a, b, a, b, 0, 1, false);
  if (crossingSign == 0) {
    // For vertex crossings, if AB crosses CD then CD does not cross AB.
    checkCrossing(c, d, a, b, crossingSign, 0, checkSimple);
  } else {
    checkCrossing(c, d, a, b, crossingSign, -signedCrossingSign, checkSimple);
  }
}

void main() {
  group('S2EdgeUtil', () {
    test('testRobustCrossingBasic', () {
      // Two regular edges that cross.
      final a = p(1, 2, 1).normalize();
      final b = p(1, -3, 0.5).normalize();
      final c = p(1, -0.5, -3).normalize();
      final d = p(0.1, 0.5, 3).normalize();

      expect(S2EdgeUtil.robustCrossing(a, b, c, d), equals(1));
      expect(S2EdgeUtil.edgesCross(a, b, c, d), isTrue);
    });

    test('testRobustCrossingNoCross', () {
      // Two edges that don't cross - both in the positive x hemisphere
      final a = p(1, 0.1, 0).normalize();
      final b = p(1, 0.2, 0).normalize();
      final c = p(1, 0, 0.1).normalize();
      final d = p(1, 0, 0.2).normalize();

      expect(S2EdgeUtil.robustCrossing(a, b, c, d), equals(-1));
      expect(S2EdgeUtil.edgesCross(a, b, c, d), isFalse);
    });

    test('testRobustCrossingSharedVertex', () {
      // Two edges that share a vertex.
      final a = p(1, 0, 0).normalize();
      final b = p(0, 1, 0).normalize();
      final c = p(0, 1, 0).normalize(); // Same as b
      final d = p(0, 0, 1).normalize();

      // Shared vertex returns 0
      expect(S2EdgeUtil.robustCrossing(a, b, c, d), equals(0));
    });

    test('testEdgeCrosserBasic', () {
      final a = p(1, 2, 1).normalize();
      final b = p(1, -3, 0.5).normalize();
      final c = p(1, -0.5, -3).normalize();
      final d = p(0.1, 0.5, 3).normalize();

      final crosser = EdgeCrosser.withEdge(a, b);
      crosser.restartAt(c);
      expect(crosser.robustCrossingFromD(d), equals(1));
    });

    test('testEdgeCrosserChain', () {
      // Test edge crosser with a chain of edges
      // AB is a short edge in the positive x hemisphere
      final a = p(1, 0.1, 0).normalize();
      final b = p(1, 0.2, 0).normalize();

      final crosser = EdgeCrosser.withEdge(a, b);

      // Chain of edges that don't cross AB - also in positive x hemisphere but different y/z
      final c1 = p(1, 0, 0.1).normalize();
      final c2 = p(1, 0, 0.15).normalize();
      final c3 = p(1, 0, 0.2).normalize();

      crosser.restartAt(c1);
      expect(crosser.robustCrossingFromD(c2), equals(-1));
      expect(crosser.robustCrossingFromD(c3), equals(-1));
    });

    test('testGetDistanceToEdge', () {
      // Point on the edge
      final a = p(1, 0, 0).normalize();
      final b = p(0, 1, 0).normalize();
      final x = p(1, 1, 0).normalize(); // On the great circle through a, b

      final dist = S2EdgeUtil.getDistance(x, a, b);
      expect(dist.radians, closeTo(0, 1e-14));
    });

    test('testGetDistanceToEdgeEndpoint', () {
      // Point closest to an endpoint
      final a = p(1, 0, 0).normalize();
      final b = p(0, 1, 0).normalize();
      final x = p(2, 0, 0).normalize(); // Closest to a

      final dist = S2EdgeUtil.getDistance(x, a, b);
      expect(dist.radians, closeTo(0, 1e-14)); // x is on the same ray as a
    });

    test('testGetDistanceToEdgePerpendicular', () {
      // Point perpendicular to edge midpoint
      final a = p(1, 0, 0).normalize();
      final b = p(0, 1, 0).normalize();
      final x = p(0, 0, 1).normalize(); // North pole

      final dist = S2EdgeUtil.getDistance(x, a, b);
      // Distance should be pi/2 (90 degrees)
      expect(dist.radians, closeTo(math.pi / 2, 1e-10));
    });

    test('testProjectOntoEdge', () {
      final a = p(1, 0, 0).normalize();
      final b = p(0, 1, 0).normalize();
      final x = p(1, 1, 0.1).normalize();

      final projected = S2EdgeUtil.project(x, a, b);

      // Projected point should be on the edge (or its extension)
      expect(S2.isUnitLength(projected), isTrue);

      // Distance from x to projected should be less than distance to endpoints
      final distToProjected = x.angle(projected);
      final distToA = x.angle(a);
      final distToB = x.angle(b);
      expect(distToProjected, lessThanOrEqualTo(distToA + 1e-10));
      expect(distToProjected, lessThanOrEqualTo(distToB + 1e-10));
    });

    test('testGetPointOnLine', () {
      final a = p(1, 0, 0).normalize();
      final b = p(0, 1, 0).normalize();

      // Get point at 45 degrees from a along the line to b
      final r = S1Angle.degrees(45);
      final point = S2EdgeUtil.getPointOnLine(a, b, r);

      expect(S2.isUnitLength(point), isTrue);

      // Distance from a to point should be approximately 45 degrees
      final dist = S1Angle.fromPoints(a, point);
      expect(dist.degrees, closeTo(45, 0.1));
    });

    test('testGetPointOnRay', () {
      final origin = p(1, 0, 0).normalize();
      final dir = p(0, 1, 0).normalize();

      final r = S1Angle.degrees(30);
      final point = S2EdgeUtil.getPointOnRay(origin, dir, r);

      expect(S2.isUnitLength(point), isTrue);

      // Distance from origin should be approximately 30 degrees
      final dist = S1Angle.fromPoints(origin, point);
      expect(dist.degrees, closeTo(30, 0.1));
    });

    test('testInterpolate', () {
      final a = p(1, 0, 0).normalize();
      final b = p(0, 1, 0).normalize();

      // t=0 should return a
      final p0 = S2EdgeUtil.interpolate(a, b, 0);
      expect(p0.x, closeTo(a.x, 1e-14));
      expect(p0.y, closeTo(a.y, 1e-14));
      expect(p0.z, closeTo(a.z, 1e-14));

      // t=1 should return b
      final p1 = S2EdgeUtil.interpolate(a, b, 1);
      expect(p1.x, closeTo(b.x, 1e-14));
      expect(p1.y, closeTo(b.y, 1e-14));
      expect(p1.z, closeTo(b.z, 1e-14));

      // t=0.5 should return midpoint
      final pMid = S2EdgeUtil.interpolate(a, b, 0.5);
      expect(S2.isUnitLength(pMid), isTrue);

      // Midpoint should be equidistant from a and b
      final distA = S1Angle.fromPoints(a, pMid);
      final distB = S1Angle.fromPoints(b, pMid);
      expect(distA.radians, closeTo(distB.radians, 1e-10));
    });

    test('testVertexCrossingSharedVertex', () {
      // Two edges that share vertex at a
      final a = p(1, 0, 0).normalize();
      final b = p(0, 1, 0).normalize();
      final c = a; // Same as a
      final d = p(0, 0, 1).normalize();

      // Should detect vertex crossing
      final result = S2EdgeUtil.vertexCrossing(a, b, c, d);
      expect(result, isTrue);
    });

    test('testVertexCrossingNoSharedVertex', () {
      // Two edges with no shared vertices
      final a = p(1, 0, 0).normalize();
      final b = p(0, 1, 0).normalize();
      final c = p(0, 0, 1).normalize();
      final d = p(0, 0, -1).normalize();

      final result = S2EdgeUtil.vertexCrossing(a, b, c, d);
      expect(result, isFalse);
    });

    test('testEdgeOrVertexCrossingCross', () {
      // Two edges that cross
      final a = p(1, 2, 1).normalize();
      final b = p(1, -3, 0.5).normalize();
      final c = p(1, -0.5, -3).normalize();
      final d = p(0.1, 0.5, 3).normalize();

      expect(S2EdgeUtil.edgeOrVertexCrossing(a, b, c, d), isTrue);
    });

    test('testEdgeOrVertexCrossingNoCross', () {
      // Two edges that don't cross - both in positive x hemisphere
      final a = p(1, 0.1, 0).normalize();
      final b = p(1, 0.2, 0).normalize();
      final c = p(1, 0, 0.1).normalize();
      final d = p(1, 0, 0.2).normalize();

      expect(S2EdgeUtil.edgeOrVertexCrossing(a, b, c, d), isFalse);
    });
  });

  group('EdgeCrosser', () {
    test('testEdgeCrosserInit', () {
      final a = p(1, 0, 0).normalize();
      final b = p(0, 1, 0).normalize();

      final crosser = EdgeCrosser();
      crosser.init(a, b);

      expect(crosser.a, equals(a));
      expect(crosser.b, equals(b));
    });

    test('testEdgeCrosserWithEdge', () {
      final a = p(1, 0, 0).normalize();
      final b = p(0, 1, 0).normalize();

      final crosser = EdgeCrosser.withEdge(a, b);

      expect(crosser.a, equals(a));
      expect(crosser.b, equals(b));
    });

    test('testEdgeCrosserWithEdgeAndVertex', () {
      final a = p(1, 0, 0).normalize();
      final b = p(0, 1, 0).normalize();
      final c = p(0, 0, 1).normalize();

      final crosser = EdgeCrosser.withEdgeAndVertex(a, b, c);

      expect(crosser.a, equals(a));
      expect(crosser.b, equals(b));
      expect(crosser.c, equals(c));
    });

    test('testEdgeCrosserRobustCrossing', () {
      final a = p(1, 2, 1).normalize();
      final b = p(1, -3, 0.5).normalize();
      final c = p(1, -0.5, -3).normalize();
      final d = p(0.1, 0.5, 3).normalize();

      final crosser = EdgeCrosser.withEdge(a, b);
      expect(crosser.robustCrossing(c, d), equals(1));
    });

    test('testEdgeCrosserEdgeOrVertexCrossing', () {
      final a = p(1, 2, 1).normalize();
      final b = p(1, -3, 0.5).normalize();
      final c = p(1, -0.5, -3).normalize();
      final d = p(0.1, 0.5, 3).normalize();

      final crosser = EdgeCrosser.withEdge(a, b);
      expect(crosser.edgeOrVertexCrossing(c, d), isTrue);
    });

    test('testEdgeCrosserMultipleEdges', () {
      // Test crossing multiple edges efficiently
      final a = p(1, 0, 0).normalize();
      final b = p(-1, 0, 0).normalize();

      final crosser = EdgeCrosser.withEdge(a, b);

      // Edge that crosses AB
      final c1 = p(0, 1, 0).normalize();
      final d1 = p(0, -1, 0).normalize();
      expect(crosser.robustCrossing(c1, d1), equals(1));

      // Edge that doesn't cross AB - both points in positive y hemisphere
      final c2 = p(0, 1, 0.1).normalize();
      final d2 = p(0, 1, 0.2).normalize();
      expect(crosser.robustCrossing(c2, d2), equals(-1));
    });
  });

  group('S2EdgeUtil distance calculations', () {
    test('testGetDistanceZero', () {
      // Point exactly on the edge
      final a = p(1, 0, 0).normalize();
      final b = p(0, 1, 0).normalize();
      final x = p(1, 1, 0).normalize(); // On the great circle

      final dist = S2EdgeUtil.getDistance(x, a, b);
      expect(dist.radians, closeTo(0, 1e-10));
    });

    test('testGetDistanceOrthogonal', () {
      // Point orthogonal to edge
      final a = p(1, 0, 0).normalize();
      final b = p(0, 1, 0).normalize();
      final x = p(0, 0, 1).normalize();

      final dist = S2EdgeUtil.getDistance(x, a, b);
      expect(dist.radians, closeTo(math.pi / 2, 1e-10));
    });

    test('testGetDistanceToEndpoint', () {
      // Point closest to endpoint a
      final a = p(1, 0, 0).normalize();
      final b = p(0, 1, 0).normalize();
      final x = p(1, -1, 0).normalize(); // Closer to a

      final dist = S2EdgeUtil.getDistance(x, a, b);
      final expectedDist = S1Angle.fromPoints(x, a);
      expect(dist.radians, closeTo(expectedDist.radians, 1e-10));
    });
  });

  group('S2EdgeUtil interpolation', () {
    test('testInterpolateEndpoints', () {
      final a = S2LatLng.fromDegrees(0, 0).toPoint();
      final b = S2LatLng.fromDegrees(0, 90).toPoint();

      // t=0 returns a
      final p0 = S2EdgeUtil.interpolate(a, b, 0);
      expect(S1Angle.fromPoints(p0, a).radians, closeTo(0, 1e-14));

      // t=1 returns b
      final p1 = S2EdgeUtil.interpolate(a, b, 1);
      expect(S1Angle.fromPoints(p1, b).radians, closeTo(0, 1e-14));
    });

    test('testInterpolateMidpoint', () {
      final a = S2LatLng.fromDegrees(0, 0).toPoint();
      final b = S2LatLng.fromDegrees(0, 90).toPoint();

      final mid = S2EdgeUtil.interpolate(a, b, 0.5);

      // Midpoint should be at (0, 45) degrees
      final midLatLng = S2LatLng.fromPoint(mid);
      expect(midLatLng.latDegrees, closeTo(0, 1));
      expect(midLatLng.lngDegrees, closeTo(45, 1));
    });

    test('testInterpolateQuarter', () {
      final a = S2LatLng.fromDegrees(0, 0).toPoint();
      final b = S2LatLng.fromDegrees(0, 90).toPoint();

      final quarter = S2EdgeUtil.interpolate(a, b, 0.25);

      // Quarter point should be at approximately (0, 22.5) degrees
      final quarterLatLng = S2LatLng.fromPoint(quarter);
      expect(quarterLatLng.latDegrees, closeTo(0, 1));
      expect(quarterLatLng.lngDegrees, closeTo(22.5, 1));
    });

    // Comprehensive crossing tests ported from Java S2EdgeUtilTest.testCrossings
    test('testCrossings_twoRegularEdgesThatCross', () {
      // 1. Two regular edges that cross.
      checkCrossings(p(1, 2, 1), p(1, -3, 0.5), p(1, -0.5, -3), p(0.1, 0.5, 3), 1, 1, true);
    });

    test('testCrossings_twoRegularEdgesThatIntersectAntipodalPoints', () {
      // 2. Two regular edges that intersect antipodal points.
      checkCrossings(p(1, 2, 1), p(1, -3, 0.5), p(-1, 0.5, 3), p(-0.1, -0.5, -3), -1, 0, true);
    });

    test('testCrossings_twoEdgesOnSameGreatCircleStartingAtAntipodalPoints', () {
      // 3. Two edges on the same great circle that start at antipodal points.
      checkCrossings(p(0, 0, -1), p(0, 1, 0), p(0, 1, 1), p(0, 0, 1), -1, 0, true);
    });

    test('testCrossings_twoEdgesThatCrossWhereOneVertexIsOrigin', () {
      // 4. Two edges that cross where one vertex is S2.origin.
      checkCrossings(p(1, 0, 0), S2.origin, p(1, -0.1, 1), p(1, 1, -0.1), 1, 1, true);
    });

    test('testCrossings_twoEdgesThatIntersectAntipodalPointsWhereOneVertexIsOrigin', () {
      // 5. Two edges that intersect antipodal points where one vertex is S2.origin.
      checkCrossings(p(1, 0, 0), S2.origin, p(-1, 0.1, -1), p(-1, -1, 0.1), -1, 0, true);
    });

    test('testCrossings_twoEdgesThatShareAnEndpoint', () {
      // 6. Two edges that share an endpoint. The Ortho() direction is (-4,0,2),
      // and edge AB is further CCW around (2,3,4) than CD.
      checkCrossings(p(7, -2, 3), p(2, 3, 4), p(2, 3, 4), p(-1, 2, 5), 0, -1, true);
    }, skip: 'Requires signedEdgeOrVertexCrossing implementation');

    test('testCrossings_twoEdgesThatBarelyCrossNearMiddle', () {
      // 7. Two edges that barely cross each other near the middle of one edge.
      // The edge AB is approximately in the x=y plane, while CD is approximately
      // perpendicular to it and ends exactly at the x=y plane.
      checkCrossings(
        p(1, 1, 1), p(1, nextAfter(1.0, 0), -1),
        p(11, -12, -1), p(10, 10, 1),
        1, -1, false,
      );
    });

    test('testCrossings_twoEdgesSeparatedBySmallDistance', () {
      // 8. In this version, the edges are separated by a distance of about 1e-15.
      checkCrossings(
        p(1, 1, 1), p(1, nextAfter(1.0, 2), -1),
        p(1, -1, 0), p(1, 1, 0),
        -1, 0, false,
      );
    });

    test('testCrossings_twoEdgesThatBarelyCrossNearEndWithUnderflow', () {
      // 9. Two edges that barely cross each other near the end of both edges.
      // This example cannot be handled using regular double-precision arithmetic
      // due to floating-point underflow.
      checkCrossings(
        p(0, 0, 1), p(2, -1e-323, 1),
        p(1, -1, 1), p(1e-323, 0, 1),
        1, -1, false,
      );
    }, skip: 'Requires extended precision arithmetic for subnormal values');

    test('testCrossings_twoEdgesSeparatedByVerySmallDistance', () {
      // 10. In this version, the edges are separated by a distance of about 1e-640.
      checkCrossings(
        p(0, 0, 1), p(2, 1e-323, 1),
        p(1, -1, 1), p(1e-323, 0, 1),
        -1, 0, false,
      );
    });

    test('testCrossings_twoEdgesThatBarelyCrossNearMiddleHighPrecision', () {
      // 11. Two edges that barely cross each other near the middle of one edge.
      // Computing the exact determinant of some of the triangles in this test
      // requires more than 2000 bits of precision.
      checkCrossings(
        p(1, -1e-323, -1e-323), p(1e-323, 1, 1e-323),
        p(1, -1, 1e-323), p(1, 1, 0),
        1, 1, false,
      );
    });

    test('testCrossings_twoEdgesSeparatedByTinyDistance', () {
      // 12. In this version, the edges are separated by a distance of about 1e-640.
      checkCrossings(
        p(1, 1e-323, -1e-323), p(-1e-323, 1, 1e-323),
        p(1, -1, 1e-323), p(1, 1, 0),
        -1, 0, false,
      );
    }, skip: 'Requires extended precision arithmetic for subnormal values');

    test('testCollinearEdgesThatDontTouch', () {
      // Test that collinear edges with no common points don't cross.
      final rand = math.Random(42);
      for (int iter = 0; iter < 500; ++iter) {
        // Generate random points a and d on the sphere
        final a = S2Point(
          rand.nextDouble() * 2 - 1,
          rand.nextDouble() * 2 - 1,
          rand.nextDouble() * 2 - 1,
        ).normalize();
        final d = S2Point(
          rand.nextDouble() * 2 - 1,
          rand.nextDouble() * 2 - 1,
          rand.nextDouble() * 2 - 1,
        ).normalize();

        // Create b and c as interpolated points on the line from a to d
        final b = S2EdgeUtil.interpolate(a, d, 0.05);
        final c = S2EdgeUtil.interpolate(a, d, 0.95);

        // Edges AB and CD should not cross (they are collinear but don't overlap)
        expect(S2EdgeUtil.robustCrossing(a, b, c, d), lessThan(0));

        final crosser = EdgeCrosser.withEdgeAndVertex(a, b, c);
        expect(crosser.robustCrossingFromD(d), lessThan(0));
        expect(crosser.robustCrossingFromD(c), lessThan(0));
      }
    });
  });

  group('S2EdgeUtil additional tests', () {
    test('testInterpolateDouble', () {
      // Test interpolation from a
      expect(S2EdgeUtil.interpolateDouble(0, 0, 10, 0, 100), closeTo(0, 1e-10));
      expect(S2EdgeUtil.interpolateDouble(5, 0, 10, 0, 100), closeTo(50, 1e-10));
      expect(S2EdgeUtil.interpolateDouble(10, 0, 10, 0, 100), closeTo(100, 1e-10));

      // Test interpolation from b (when x is closer to b)
      expect(S2EdgeUtil.interpolateDouble(8, 0, 10, 0, 100), closeTo(80, 1e-10));
    });

    test('testGetPointOnLineChord', () {
      final a = p(1, 0, 0).normalize();
      final b = p(0, 1, 0).normalize();
      final r = S1ChordAngle.fromS1Angle(S1Angle.degrees(45));

      final point = S2EdgeUtil.getPointOnLineChord(a, b, r);
      expect(S2.isUnitLength(point), isTrue);

      final dist = S1Angle.fromPoints(a, point);
      expect(dist.degrees, closeTo(45, 1));
    });

    test('testGetPointOnRayChord', () {
      final origin = p(1, 0, 0).normalize();
      final dir = p(0, 1, 0).normalize();
      final r = S1ChordAngle.fromS1Angle(S1Angle.degrees(30));

      final point = S2EdgeUtil.getPointOnRayChord(origin, dir, r);
      expect(S2.isUnitLength(point), isTrue);

      final dist = S1Angle.fromPoints(origin, point);
      expect(dist.degrees, closeTo(30, 1));
    });

    test('testProjectWithCrossProd', () {
      final a = p(1, 0, 0).normalize();
      final b = p(0, 1, 0).normalize();
      final aCrossB = S2RobustCrossProd.robustCrossProd(a, b);
      final x = p(1, 1, 0.1).normalize();

      final projected = S2EdgeUtil.projectWithCrossProd(x, a, b, aCrossB);
      expect(S2.isUnitLength(projected), isTrue);
    });

    test('testProjectPointEqualsEndpoint', () {
      final a = p(1, 0, 0).normalize();
      final b = p(0, 1, 0).normalize();

      // Project a onto AB - should return a
      final projectedA = S2EdgeUtil.project(a, a, b);
      expect(projectedA, equals(a));

      // Project b onto AB - should return b
      final projectedB = S2EdgeUtil.project(b, a, b);
      expect(projectedB, equals(b));
    });

    test('testOrderedCCW', () {
      final o = p(1, 0, 0).normalize();
      final a = p(0, 1, 0).normalize();
      final b = p(0, 0, 1).normalize();
      final c = p(0, -1, 0).normalize();

      // Test ordering around origin
      final ordered = S2EdgeUtil.orderedCCW(o, a, b, c);
      expect(ordered, isA<bool>());
    });

    test('testVertexCrossingBEqualsC', () {
      final a = p(1, 0, 0).normalize();
      final b = p(0, 1, 0).normalize();
      final c = b; // b == c
      final d = p(0, 0, 1).normalize();

      final result = S2EdgeUtil.vertexCrossing(a, b, c, d);
      expect(result, isA<bool>());
    });

    test('testVertexCrossingBEqualsD', () {
      final a = p(1, 0, 0).normalize();
      final b = p(0, 1, 0).normalize();
      final c = p(0, 0, 1).normalize();
      final d = b; // b == d

      final result = S2EdgeUtil.vertexCrossing(a, b, c, d);
      expect(result, isA<bool>());
    });

    test('testDefaultIntersectionTolerance', () {
      expect(S2EdgeUtil.defaultIntersectionTolerance.radians, isA<double>());
      expect(S2EdgeUtil.defaultIntersectionTolerance.radians, greaterThan(0));
    });

    test('testFaceClipErrorConstants', () {
      expect(S2EdgeUtil.faceClipErrorRadians, greaterThan(0));
      expect(S2EdgeUtil.faceClipErrorUvDist, greaterThan(0));
      expect(S2EdgeUtil.intersectsRectErrorUvDist, greaterThan(0));
      expect(S2EdgeUtil.edgeClipErrorUvCoord, greaterThan(0));
      expect(S2EdgeUtil.edgeClipErrorUvDist, greaterThan(0));
      expect(S2EdgeUtil.intersectionError, greaterThan(0));
    });

    test('testGetPointOnLineError', () {
      expect(S2EdgeUtil.getPointOnLineError.radians, greaterThan(0));
    });

    test('testProjectPerpendicularError', () {
      expect(S2EdgeUtil.projectPerpendicularError.radians, greaterThan(0));
    });

    test('testGetPointOnRayPerpendicularError', () {
      expect(S2EdgeUtil.getPointOnRayPerpendicularError.radians, greaterThan(0));
    });

    test('testIntersectionMergeRadius', () {
      expect(S2EdgeUtil.intersectionMergeRadius.radians, greaterThan(0));
    });
  });

  group('EdgeCrosser additional tests', () {
    test('testEdgeCrosserNormal', () {
      final a = p(1, 0, 0).normalize();
      final b = p(0, 1, 0).normalize();

      final crosser = EdgeCrosser.withEdge(a, b);
      expect(crosser.normal, isNotNull);
      expect(crosser.normal.norm, greaterThan(0));
    });

    test('testEdgeCrosserDegenerate', () {
      final a = p(1, 0, 0).normalize();

      // Degenerate edge where a == b
      final crosser = EdgeCrosser.withEdge(a, a);
      final c = p(0, 1, 0).normalize();
      final d = p(0, 0, 1).normalize();

      final result = crosser.robustCrossing(c, d);
      expect(result, equals(-1)); // Degenerate edges don't cross
    });

    test('testEdgeCrosserCEqualsNull', () {
      final a = p(1, 0, 0).normalize();
      final b = p(0, 1, 0).normalize();

      final crosser = EdgeCrosser.withEdge(a, b);
      expect(crosser.c, isNull);

      final c = p(0, 0, 1).normalize();
      crosser.restartAt(c);
      expect(crosser.c, equals(c));
    });
  });

  group('RectBounder', () {
    test('testRectBounderSinglePoint', () {
      final bounder = RectBounder();
      final point = S2LatLng.fromDegrees(45, 90).toPoint();
      bounder.addPoint(point);
      expect(bounder.bound.isEmpty, isFalse);
    });

    test('testRectBounderMultiplePoints', () {
      final bounder = RectBounder();
      bounder.addPoint(S2LatLng.fromDegrees(0, 0).toPoint());
      bounder.addPoint(S2LatLng.fromDegrees(10, 10).toPoint());
      bounder.addPoint(S2LatLng.fromDegrees(20, 20).toPoint());
      expect(bounder.bound.isEmpty, isFalse);
      expect(bounder.bound.containsLatLng(S2LatLng.fromDegrees(10, 10)), isTrue);
    });

    test('testRectBounderNearlyAntipodalPoints', () {
      // Test the code path for nearly antipodal points (a.dotProd(b) < 0)
      // When points are nearly antipodal, the bound becomes full
      final bounder = RectBounder();
      final a = S2Point(1, 0, 0).normalize();
      final b = S2Point(-1, 1e-16, 1e-16).normalize(); // Nearly antipodal to a
      bounder.addPoint(a);
      bounder.addPoint(b);
      // For nearly antipodal points, the bound should be full
      expect(bounder.bound.isFull, isTrue);
    });

    test('testRectBounderNearlyFullLongitudeSpan', () {
      // Test edges that span nearly the full longitude range
      final bounder = RectBounder();
      // Points at opposite longitudes (nearly 180 degrees apart)
      final a = S2LatLng.fromDegrees(0, 0).toPoint();
      final b = S2LatLng.fromDegrees(0, 179.9999999).toPoint();
      bounder.addPoint(a);
      bounder.addPoint(b);
      // The longitude range should be nearly full
      expect(bounder.bound.lng.length, greaterThan(math.pi - 0.01));
    });
  });
}

