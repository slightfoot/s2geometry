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
  });
}

