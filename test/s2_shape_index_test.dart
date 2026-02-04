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

import 'package:s2geometry/s2geometry.dart';
import 'package:test/test.dart';

void main() {
  group('S2ShapeIndex', () {
    test('testNoEdges', () {
      final index = S2ShapeIndex();
      final it = index.iterator();
      expect(it.done, isTrue);
    });

    test('testOneEdge', () {
      final index = S2ShapeIndex();
      final shape = S2EdgeVectorShape.single(S2Point.xPos, S2Point.yPos);
      index.add(shape);
      final it = index.iterator();
      expect(it.done, isFalse);
      // Should have at least one cell
      int cellCount = 0;
      while (!it.done) {
        cellCount++;
        it.next();
      }
      expect(cellCount, greaterThan(0));
    });

    test('testManyIdenticalEdges', () {
      final a = S2Point(0.99, 0.99, 1).normalize();
      final b = S2Point(-0.99, -0.99, 1).normalize();
      final index = S2ShapeIndex();
      for (int i = 0; i < 100; i++) {
        index.add(S2EdgeVectorShape.single(a, b));
      }
      final it = index.iterator();
      // Since all edges span the diagonal of a face, no subdivision should occur
      while (!it.done) {
        expect(it.cellId.level, equals(0));
        it.next();
      }
    });

    test('testManyTinyEdges', () {
      // Construct two points in the same leaf cell.
      final a = S2CellId.fromPoint(S2Point.xPos).toPoint();
      final b = (a + S2Point(0, 1e-12, 0)).normalize();
      final shape = S2EdgeVectorShape();
      for (int i = 0; i < 100; i++) {
        shape.add(a, b);
      }
      final index = S2ShapeIndex();
      index.add(shape);
      // Check that there is exactly one index cell and that it is a leaf cell.
      final it = index.iterator();
      expect(it.done, isFalse);
      expect(it.cellId.isLeaf, isTrue);
      it.next();
      expect(it.done, isTrue);
    });

    test('testIteratorMethods', () {
      final index = S2ShapeIndex();
      index.add(S2EdgeVectorShape.single(S2Point.xPos, S2Point.yPos));

      final it = index.iterator();
      expect(it.atBegin, isTrue);

      it.finish();
      expect(it.done, isTrue);

      it.restart();
      expect(it.atBegin, isTrue);
      expect(it.done, isFalse);
    });

    test('testAddAndReset', () {
      final index = S2ShapeIndex();
      expect(index.numShapes, equals(0));

      index.add(S2EdgeVectorShape.single(S2Point.xPos, S2Point.yPos));
      expect(index.numShapes, equals(1));

      index.add(S2EdgeVectorShape.single(S2Point.yPos, S2Point.zPos));
      expect(index.numShapes, equals(2));

      index.reset();
      expect(index.numShapes, equals(0));
    });

    test('testOptions', () {
      final options = S2ShapeIndexOptions();
      expect(options.maxEdgesPerCell, equals(defaultMaxEdgesPerCell));
      expect(options.cellSizeToLongEdgeRatio, equals(defaultCellSizeToLongEdgeRatio));
      expect(options.minShortEdgeFraction, equals(defaultMinShortEdgeFraction));

      options.maxEdgesPerCell = 20;
      expect(options.maxEdgesPerCell, equals(20));

      final index = S2ShapeIndex.withOptions(options);
      expect(index.options.maxEdgesPerCell, equals(20));
    });

    test('testCellRelation', () {
      expect(CellRelation.values.length, equals(3));
      expect(CellRelation.indexed.index, equals(0));
      expect(CellRelation.subdivided.index, equals(1));
      expect(CellRelation.disjoint.index, equals(2));
    });

    test('testS2ClippedShape', () {
      final cellId = S2CellId.fromFace(0);

      // Test contained shape
      final contained = S2ClippedShape.createContained(cellId, 5);
      expect(contained.shapeId, equals(5));
      expect(contained.containsCenter, isTrue);
      expect(contained.numEdges, equals(0));

      // Test one edge shape
      final oneEdge = S2ClippedShape.createOneEdge(cellId, 3, false, 42);
      expect(oneEdge.shapeId, equals(3));
      expect(oneEdge.containsCenter, isFalse);
      expect(oneEdge.numEdges, equals(1));
      expect(oneEdge.edge(0), equals(42));

      // Test many edges shape
      final manyEdges = S2ClippedShape.createManyEdges(cellId, 7, true, [1, 3, 5, 7]);
      expect(manyEdges.shapeId, equals(7));
      expect(manyEdges.containsCenter, isTrue);
      expect(manyEdges.numEdges, equals(4));
      expect(manyEdges.edge(0), equals(1));
      expect(manyEdges.edge(3), equals(7));
    });
  });
}

