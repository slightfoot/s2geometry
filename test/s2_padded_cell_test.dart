// Copyright 2014 Google Inc.
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

/// Port of S2PaddedCellTest.java from the S2 Geometry library.
library;

import 'dart:math';

import 'package:s2geometry/s2geometry.dart';
import 'package:test/test.dart';

void main() {
  group('S2PaddedCell', () {
    test('testBasicProperties', () {
      // Test basic properties with a face cell.
      final id = S2CellId.fromFace(0);
      final padding = 0.1;
      final pcell = S2PaddedCell(id, padding);

      expect(pcell.id, equals(id));
      expect(pcell.level, equals(0));
      expect(pcell.padding, equals(padding));
      expect(pcell.bound, isNotNull);
    });

    test('testLeafCell', () {
      // Test with a leaf cell.
      final point = S2LatLng.fromDegrees(37.7749, -122.4194).toPoint();
      final id = S2CellId.fromPoint(point);
      final padding = 0.01;
      final pcell = S2PaddedCell(id, padding);

      expect(pcell.id, equals(id));
      expect(pcell.level, equals(S2CellId.maxLevel));
      expect(pcell.padding, equals(padding));
    });

    test('testS2CellMethods', () {
      // Test S2PaddedCell methods that have S2Cell equivalents.
      final random = Random(42);
      for (int i = 0; i < 100; i++) {
        // Generate random cell using a random point
        final x = random.nextDouble() * 2 - 1;
        final y = random.nextDouble() * 2 - 1;
        final z = random.nextDouble() * 2 - 1;
        final point = S2Point(x, y, z).normalize();
        final level = random.nextInt(S2CellId.maxLevel + 1);
        final id = S2CellId.fromPoint(point).parentAtLevel(level);

        final padding = pow(1e-15, random.nextDouble()).toDouble();
        final cell = S2Cell(id);
        final pcell = S2PaddedCell(id, padding);

        // Compare S2Cell to S2PaddedCell
        expect(pcell.id, equals(cell.id));
        expect(pcell.level, equals(cell.level));
        expect(pcell.padding, equals(padding));
        expect(pcell.bound, equals(cell.boundUV.expanded(padding)));
      }
    });

    test('testMiddle', () {
      // Test the middle() method.
      final id = S2CellId.fromFace(0);
      final padding = 0.25;
      final pcell = S2PaddedCell(id, padding);

      final middle = pcell.middle();
      expect(middle, isNotNull);

      // For a face cell with padding 0.25, the middle rectangle should be a
      // square with width 2*padding centered around the cell center.
      expect(middle.x.hi - middle.x.lo, closeTo(2 * padding, 1e-10));
      expect(middle.y.hi - middle.y.lo, closeTo(2 * padding, 1e-10));
    });

    test('testChildAtPos', () {
      // Test child traversal using position.
      final id = S2CellId.fromFace(0);
      final padding = 0.1;
      final pcell = S2PaddedCell(id, padding);

      // Get all four children.
      for (int pos = 0; pos < 4; pos++) {
        final child = pcell.childAtPos(pos);
        expect(child.level, equals(1));
        expect(child.padding, equals(padding));
      }
    });

    test('testChildAtIJ', () {
      // Test child traversal using (i,j) coordinates.
      final id = S2CellId.fromFace(0);
      final padding = 0.1;
      final pcell = S2PaddedCell(id, padding);

      // Get all four children using (i,j).
      for (int i = 0; i < 2; i++) {
        for (int j = 0; j < 2; j++) {
          final child = pcell.childAtIJ(i, j);
          expect(child.level, equals(1));
          expect(child.padding, equals(padding));
        }
      }
    });

    test('testGetCenter', () {
      // Test that getCenter returns a valid point.
      final id = S2CellId.fromFace(0);
      final padding = 0.1;
      final pcell = S2PaddedCell(id, padding);

      final center = pcell.getCenter();
      expect(center.norm, closeTo(1.0, 1e-10));
    });

    test('testGetEntryExitVertices', () {
      // Test entry and exit vertices.
      final id = S2CellId.fromFace(0);
      final pcell0 = S2PaddedCell(id, 0.0);
      final pcell1 = S2PaddedCell(id, 0.5);

      // Entry/exit vertices should not depend on padding.
      expect(pcell0.getEntryVertex(), equals(pcell1.getEntryVertex()));
      expect(pcell0.getExitVertex(), equals(pcell1.getExitVertex()));
    });

    test('testEntryExitConsistency', () {
      // Check that exit vertex of one cell equals entry vertex of next.
      // Use a mid-level cell to avoid edge cases at face boundaries.
      final id = S2CellId.fromFacePosLevel(0, 0, 5);
      final exitVertex = S2PaddedCell(id, 0.0).getExitVertex();
      // Use next instead of nextWrap (which isn't ported yet)
      final nextEntry = S2PaddedCell(id.next, 0.0).getEntryVertex();
      expect(exitVertex, equals(nextEntry));
    });
  });
}

