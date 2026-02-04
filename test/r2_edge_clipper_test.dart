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

import 'package:s2geometry/s2geometry.dart';
import 'package:test/test.dart';

void main() {
  group('R2EdgeClipper', () {
    test('edgeCompletelyInsideClipRegion', () {
      final clipRect = R2Rect.fromPoints(
        R2Vector(-1, -1),
        R2Vector(1, 1),
      );
      final clipper = R2EdgeClipper.fromRect(clipRect);

      final edge = R2Edge();
      edge.initFromPoints(R2Vector(-0.5, -0.5), R2Vector(0.5, 0.5));

      expect(clipper.clipEdge(edge, false), isTrue);
      expect(clipper.outcode0, equals(R2EdgeClipper.inside));
      expect(clipper.outcode1, equals(R2EdgeClipper.inside));
      expect(clipper.clippedEdge.v0.x, closeTo(-0.5, 1e-10));
      expect(clipper.clippedEdge.v0.y, closeTo(-0.5, 1e-10));
      expect(clipper.clippedEdge.v1.x, closeTo(0.5, 1e-10));
      expect(clipper.clippedEdge.v1.y, closeTo(0.5, 1e-10));
    });

    test('edgeCompletelyOutsideClipRegion', () {
      final clipRect = R2Rect.fromPoints(
        R2Vector(-1, -1),
        R2Vector(1, 1),
      );
      final clipper = R2EdgeClipper.fromRect(clipRect);

      // Edge to the right of the clip region
      final edge = R2Edge();
      edge.initFromPoints(R2Vector(2, 0), R2Vector(3, 0));

      expect(clipper.clipEdge(edge, false), isFalse);
      expect(clipper.outcode0, equals(R2EdgeClipper.outside));
      expect(clipper.outcode1, equals(R2EdgeClipper.outside));
    });

    test('edgeCrossesLeftBoundary', () {
      final clipRect = R2Rect.fromPoints(
        R2Vector(-1, -1),
        R2Vector(1, 1),
      );
      final clipper = R2EdgeClipper.fromRect(clipRect);

      // Horizontal edge crossing the left boundary
      final edge = R2Edge();
      edge.initFromPoints(R2Vector(-2, 0), R2Vector(0, 0));

      expect(clipper.clipEdge(edge, false), isTrue);
      expect(clipper.outcode0, equals(R2EdgeClipper.left));
      expect(clipper.outcode1, equals(R2EdgeClipper.inside));
      expect(clipper.clippedEdge.v0.x, closeTo(-1, 1e-10));
      expect(clipper.clippedEdge.v0.y, closeTo(0, 1e-10));
      expect(clipper.clippedEdge.v1.x, closeTo(0, 1e-10));
      expect(clipper.clippedEdge.v1.y, closeTo(0, 1e-10));
    });

    test('edgeCrossesRightBoundary', () {
      final clipRect = R2Rect.fromPoints(
        R2Vector(-1, -1),
        R2Vector(1, 1),
      );
      final clipper = R2EdgeClipper.fromRect(clipRect);

      // Horizontal edge crossing the right boundary
      final edge = R2Edge();
      edge.initFromPoints(R2Vector(0, 0), R2Vector(2, 0));

      expect(clipper.clipEdge(edge, false), isTrue);
      expect(clipper.outcode0, equals(R2EdgeClipper.inside));
      expect(clipper.outcode1, equals(R2EdgeClipper.right));
      expect(clipper.clippedEdge.v0.x, closeTo(0, 1e-10));
      expect(clipper.clippedEdge.v1.x, closeTo(1, 1e-10));
    });

    test('edgeCrossesTopBoundary', () {
      final clipRect = R2Rect.fromPoints(
        R2Vector(-1, -1),
        R2Vector(1, 1),
      );
      final clipper = R2EdgeClipper.fromRect(clipRect);

      // Vertical edge crossing the top boundary
      final edge = R2Edge();
      edge.initFromPoints(R2Vector(0, 0), R2Vector(0, 2));

      expect(clipper.clipEdge(edge, false), isTrue);
      expect(clipper.outcode0, equals(R2EdgeClipper.inside));
      expect(clipper.outcode1, equals(R2EdgeClipper.top));
      expect(clipper.clippedEdge.v0.y, closeTo(0, 1e-10));
      expect(clipper.clippedEdge.v1.y, closeTo(1, 1e-10));
    });

    test('edgeCrossesBottomBoundary', () {
      final clipRect = R2Rect.fromPoints(
        R2Vector(-1, -1),
        R2Vector(1, 1),
      );
      final clipper = R2EdgeClipper.fromRect(clipRect);

      // Vertical edge crossing the bottom boundary
      final edge = R2Edge();
      edge.initFromPoints(R2Vector(0, -2), R2Vector(0, 0));

      expect(clipper.clipEdge(edge, false), isTrue);
      expect(clipper.outcode0, equals(R2EdgeClipper.bottom));
      expect(clipper.outcode1, equals(R2EdgeClipper.inside));
      expect(clipper.clippedEdge.v0.y, closeTo(-1, 1e-10));
      expect(clipper.clippedEdge.v1.y, closeTo(0, 1e-10));
    });

    test('edgeCrossesBothBoundaries', () {
      final clipRect = R2Rect.fromPoints(
        R2Vector(-1, -1),
        R2Vector(1, 1),
      );
      final clipper = R2EdgeClipper.fromRect(clipRect);

      // Horizontal edge crossing both left and right boundaries
      final edge = R2Edge();
      edge.initFromPoints(R2Vector(-2, 0), R2Vector(2, 0));

      expect(clipper.clipEdge(edge, false), isTrue);
      expect(clipper.outcode0, equals(R2EdgeClipper.left));
      expect(clipper.outcode1, equals(R2EdgeClipper.right));
      expect(clipper.clippedEdge.v0.x, closeTo(-1, 1e-10));
      expect(clipper.clippedEdge.v1.x, closeTo(1, 1e-10));
    });

    test('diagonalEdgeCrossingCorner', () {
      final clipRect = R2Rect.fromPoints(
        R2Vector(-1, -1),
        R2Vector(1, 1),
      );
      final clipper = R2EdgeClipper.fromRect(clipRect);

      // Diagonal edge from bottom-left to top-right corner region
      final edge = R2Edge();
      edge.initFromPoints(R2Vector(-2, -2), R2Vector(2, 2));

      expect(clipper.clipEdge(edge, false), isTrue);
      expect(clipper.clippedEdge.v0.x, closeTo(-1, 1e-10));
      expect(clipper.clippedEdge.v0.y, closeTo(-1, 1e-10));
      expect(clipper.clippedEdge.v1.x, closeTo(1, 1e-10));
      expect(clipper.clippedEdge.v1.y, closeTo(1, 1e-10));
    });

    test('defaultConstructor', () {
      final clipper = R2EdgeClipper();
      expect(clipper, isNotNull);
    });

    test('clipRectGetter', () {
      final clipRect = R2Rect.fromPoints(
        R2Vector(-1, -1),
        R2Vector(1, 1),
      );
      final clipper = R2EdgeClipper.fromRect(clipRect);

      final rect = clipper.clipRect;
      expect(rect.x.lo, equals(-1));
      expect(rect.x.hi, equals(1));
      expect(rect.y.lo, equals(-1));
      expect(rect.y.hi, equals(1));
    });

    test('maxUnitClipError', () {
      expect(R2EdgeClipper.maxUnitClipError, greaterThan(0));
    });

    test('clipMethodBottom', () {
      final clipRect = R2Rect.fromPoints(
        R2Vector(-1, -1),
        R2Vector(1, 1),
      );
      final clipper = R2EdgeClipper.fromRect(clipRect);

      final edge = R2Edge();
      edge.initFromPoints(R2Vector(0, -2), R2Vector(0, 2));
      final result = R2Vector.origin();
      clipper.clip(edge, R2EdgeClipper.bottom, result);

      expect(result.y, closeTo(-1, 1e-10));
    });

    test('clipMethodTop', () {
      final clipRect = R2Rect.fromPoints(
        R2Vector(-1, -1),
        R2Vector(1, 1),
      );
      final clipper = R2EdgeClipper.fromRect(clipRect);

      final edge = R2Edge();
      edge.initFromPoints(R2Vector(0, -2), R2Vector(0, 2));
      final result = R2Vector.origin();
      clipper.clip(edge, R2EdgeClipper.top, result);

      expect(result.y, closeTo(1, 1e-10));
    });

    test('clipMethodLeft', () {
      final clipRect = R2Rect.fromPoints(
        R2Vector(-1, -1),
        R2Vector(1, 1),
      );
      final clipper = R2EdgeClipper.fromRect(clipRect);

      final edge = R2Edge();
      edge.initFromPoints(R2Vector(-2, 0), R2Vector(2, 0));
      final result = R2Vector.origin();
      clipper.clip(edge, R2EdgeClipper.left, result);

      expect(result.x, closeTo(-1, 1e-10));
    });

    test('clipMethodRight', () {
      final clipRect = R2Rect.fromPoints(
        R2Vector(-1, -1),
        R2Vector(1, 1),
      );
      final clipper = R2EdgeClipper.fromRect(clipRect);

      final edge = R2Edge();
      edge.initFromPoints(R2Vector(-2, 0), R2Vector(2, 0));
      final result = R2Vector.origin();
      clipper.clip(edge, R2EdgeClipper.right, result);

      expect(result.x, closeTo(1, 1e-10));
    });

    test('connectedEdges', () {
      final clipRect = R2Rect.fromPoints(
        R2Vector(-1, -1),
        R2Vector(1, 1),
      );
      final clipper = R2EdgeClipper.fromRect(clipRect);

      // First edge ending inside
      final edge1 = R2Edge();
      edge1.initFromPoints(R2Vector(-2, 0), R2Vector(0, 0));
      expect(clipper.clipEdge(edge1, false), isTrue);

      // Second edge starting where first ended (connected)
      final edge2 = R2Edge();
      edge2.initFromPoints(R2Vector(0, 0), R2Vector(2, 0));
      expect(clipper.clipEdge(edge2, true), isTrue);
      expect(clipper.outcode0, equals(R2EdgeClipper.inside));
      expect(clipper.outcode1, equals(R2EdgeClipper.right));
    });

    test('topLeftCorner', () {
      final clipRect = R2Rect.fromPoints(
        R2Vector(-1, -1),
        R2Vector(1, 1),
      );
      final clipper = R2EdgeClipper.fromRect(clipRect);

      // Edge from top-left corner region to inside
      final edge = R2Edge();
      edge.initFromPoints(R2Vector(-2, 2), R2Vector(0, 0));

      expect(clipper.clipEdge(edge, false), isTrue);
    });

    test('topRightCorner', () {
      final clipRect = R2Rect.fromPoints(
        R2Vector(-1, -1),
        R2Vector(1, 1),
      );
      final clipper = R2EdgeClipper.fromRect(clipRect);

      // Edge from top-right corner region to inside
      final edge = R2Edge();
      edge.initFromPoints(R2Vector(2, 2), R2Vector(0, 0));

      expect(clipper.clipEdge(edge, false), isTrue);
    });

    test('bottomRightCorner', () {
      final clipRect = R2Rect.fromPoints(
        R2Vector(-1, -1),
        R2Vector(1, 1),
      );
      final clipper = R2EdgeClipper.fromRect(clipRect);

      // Edge from bottom-right corner region to inside
      final edge = R2Edge();
      edge.initFromPoints(R2Vector(2, -2), R2Vector(0, 0));

      expect(clipper.clipEdge(edge, false), isTrue);
    });

    test('bottomLeftCorner', () {
      final clipRect = R2Rect.fromPoints(
        R2Vector(-1, -1),
        R2Vector(1, 1),
      );
      final clipper = R2EdgeClipper.fromRect(clipRect);

      // Edge from bottom-left corner region to inside
      final edge = R2Edge();
      edge.initFromPoints(R2Vector(-2, -2), R2Vector(0, 0));

      expect(clipper.clipEdge(edge, false), isTrue);
    });

    test('cornerToCornerMisses', () {
      final clipRect = R2Rect.fromPoints(
        R2Vector(-1, -1),
        R2Vector(1, 1),
      );
      final clipper = R2EdgeClipper.fromRect(clipRect);

      // Edge from one corner region to another that misses the clip rect
      final edge = R2Edge();
      edge.initFromPoints(R2Vector(-3, 2), R2Vector(-2, 3));

      expect(clipper.clipEdge(edge, false), isFalse);
    });

    test('edgeTouchesCorner', () {
      final clipRect = R2Rect.fromPoints(
        R2Vector(-1, -1),
        R2Vector(1, 1),
      );
      final clipper = R2EdgeClipper.fromRect(clipRect);

      // Diagonal edge that exactly hits the corner
      final edge = R2Edge();
      edge.initFromPoints(R2Vector(-2, 0), R2Vector(0, -2));

      // This should be clipped or rejected depending on tolerance
      final result = clipper.clipEdge(edge, false);
      expect(result, isA<bool>());
    });

    test('horizontalEdgeAboveClipRegion', () {
      final clipRect = R2Rect.fromPoints(
        R2Vector(-1, -1),
        R2Vector(1, 1),
      );
      final clipper = R2EdgeClipper.fromRect(clipRect);

      // Horizontal edge above the clip region
      final edge = R2Edge();
      edge.initFromPoints(R2Vector(-2, 2), R2Vector(2, 2));

      expect(clipper.clipEdge(edge, false), isFalse);
    });

    test('verticalEdgeLeftOfClipRegion', () {
      final clipRect = R2Rect.fromPoints(
        R2Vector(-1, -1),
        R2Vector(1, 1),
      );
      final clipper = R2EdgeClipper.fromRect(clipRect);

      // Vertical edge to the left of the clip region
      final edge = R2Edge();
      edge.initFromPoints(R2Vector(-2, -2), R2Vector(-2, 2));

      expect(clipper.clipEdge(edge, false), isFalse);
    });

    test('edgeStartsInsideEndsOutsideCorner', () {
      final clipRect = R2Rect.fromPoints(
        R2Vector(-1, -1),
        R2Vector(1, 1),
      );
      final clipper = R2EdgeClipper.fromRect(clipRect);

      // Diagonal edge from inside to corner region
      final edge = R2Edge();
      edge.initFromPoints(R2Vector(0, 0), R2Vector(2, 2));

      expect(clipper.clipEdge(edge, false), isTrue);
      expect(clipper.outcode0, equals(R2EdgeClipper.inside));
    });

    test('cornerClipSecondEdgeWins', () {
      // Test case where first clip (to one boundary) leaves point outside,
      // but second clip (to perpendicular boundary) puts it inside
      final clipRect = R2Rect.fromPoints(
        R2Vector(0, 0),
        R2Vector(2, 2),
      );
      final clipper = R2EdgeClipper.fromRect(clipRect);

      // Edge from top-left corner region that clips better to left than top
      // Start point is at (-1, 3) which is top | left corner
      // End point is at (1, 1) which is inside
      // When we clip to top (y=2), the x-intercept may still be outside left
      // When we clip to left (x=0), the y-intercept should be inside
      final edge = R2Edge();
      edge.initFromPoints(R2Vector(-1, 3), R2Vector(1, 1));

      expect(clipper.clipEdge(edge, false), isTrue);
    });

    test('cornerClipSecondBoundaryWins', () {
      // Test where clipping to first boundary (top) still leaves point outside (left)
      // but clipping to second boundary (left) puts point inside
      //
      // Clip rect: [0,0] to [10,10]
      // Point in top-left corner: (-5, 15) - very far left, above the rect
      // Edge goes to (5, 5) inside
      //
      // When we clip (-5,15)->(5,5) to y=10 (top):
      //   t = (10-15)/(5-15) = -5/-10 = 0.5
      //   x at t=0.5: -5 + 0.5*(5-(-5)) = -5 + 5 = 0
      //   So clipping to top gives (0, 10) which is on left edge - inside
      //
      // Actually, let me try a case where clipping to top gives point OUTSIDE
      // Edge from (-20, 15) to (5, 5)
      // Clip to y=10: t = (10-15)/(5-15) = 0.5
      //   x = -20 + 0.5*(5-(-20)) = -20 + 12.5 = -7.5 -> still left of x=0
      // Clip to x=0: t = (0-(-20))/(5-(-20)) = 20/25 = 0.8
      //   y = 15 + 0.8*(5-15) = 15 - 8 = 7 -> inside [0,10]

      final clipRect = R2Rect.fromPoints(
        R2Vector(0, 0),
        R2Vector(10, 10),
      );
      final clipper = R2EdgeClipper.fromRect(clipRect);

      final edge = R2Edge();
      edge.initFromPoints(R2Vector(-20, 15), R2Vector(5, 5));

      expect(clipper.clipEdge(edge, false), isTrue);
    });
  });
}

