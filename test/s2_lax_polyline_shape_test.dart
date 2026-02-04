// Copyright 2019 Google Inc.
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
  group('S2LaxPolylineShape', () {
    final a = S2TextFormat.makePointOrDie('0:0');
    final b = S2TextFormat.makePointOrDie('0:1');
    final c = S2TextFormat.makePointOrDie('1:1');
    final vertices = [a, b, c];

    test('testNoVertices', () {
      final shape = S2LaxPolylineShape.create([]);
      expect(shape.isEmpty, isTrue);
      expect(shape.isFull, isFalse);
      expect(shape.numEdges, equals(0));
      expect(shape.numChains, equals(0));
    });

    test('testOneVertex', () {
      final line = S2LaxPolylineShape.create([S2Point(1, 0, 0)]);
      // Note that the C++ lax polyline stores a vertex, but there is no way to access it,
      // whereas we discard it during construction.
      expect(line.numVertices, equals(0));
      expect(line.numEdges, equals(0));
      expect(line.numChains, equals(0));
      expect(line.isEmpty, isTrue);
      expect(line.isFull, isFalse);
    });

    test('testFromDegenerateS2Polyline', () {
      final s2Polyline = S2Polyline([S2Point(1, 0, 0)]);
      final line = S2LaxPolylineShape.fromPolyline(s2Polyline);
      // An S2Polyline with a single point represents a degenerate edge.
      // The create method must convert to the S2LaxPolylineShape representation
      // which uses two identical vertices.
      expect(line.numVertices, equals(2));
      expect(line.numEdges, equals(1));
      expect(line.numChains, equals(1));
      expect(line.isEmpty, isFalse);
    });

    test('testTwoEdges', () {
      final shape = S2LaxPolylineShape.create(vertices);
      expect(shape.dimension, equals(1));
      expect(shape.isEmpty, isFalse);
      expect(shape.isFull, isFalse);
      expect(shape.numEdges, equals(2));
      expect(shape.numChains, equals(1));

      // Verify edge 0: a -> b
      final edge = MutableEdge();
      shape.getEdge(0, edge);
      expect(edge.a, equals(a));
      expect(edge.b, equals(b));

      // Verify edge 1: b -> c
      shape.getEdge(1, edge);
      expect(edge.a, equals(b));
      expect(edge.b, equals(c));
    });

    test('testChainMethods', () {
      final shape = S2LaxPolylineShape.create(vertices);
      expect(shape.numChains, equals(1));
      expect(shape.getChainStart(0), equals(0));
      expect(shape.getChainLength(0), equals(2));

      final edge = MutableEdge();
      shape.getChainEdge(0, 0, edge);
      expect(edge.a, equals(a));
      expect(edge.b, equals(b));

      shape.getChainEdge(0, 1, edge);
      expect(edge.a, equals(b));
      expect(edge.b, equals(c));

      expect(shape.getChainVertex(0, 0), equals(a));
      expect(shape.getChainVertex(0, 1), equals(b));
      expect(shape.getChainVertex(0, 2), equals(c));

      final position = ChainPosition();
      shape.getChainPosition(0, position);
      expect(position.chainId, equals(0));
      expect(position.offset, equals(0));

      shape.getChainPosition(1, position);
      expect(position.chainId, equals(0));
      expect(position.offset, equals(1));
    });

    test('testEmptyConstant', () {
      expect(S2LaxPolylineShape.empty.isEmpty, isTrue);
      expect(S2LaxPolylineShape.empty.numEdges, equals(0));
      expect(S2LaxPolylineShape.empty.numVertices, equals(0));
    });

    test('testFromPolylineWithMultipleVertices', () {
      final polyline = S2TextFormat.makePolylineOrDie('1:1, 2:2, 3:3');
      final shape = S2LaxPolylineShape.fromPolyline(polyline);
      expect(shape.numVertices, equals(3));
      expect(shape.numEdges, equals(2));
      expect(shape.numChains, equals(1));
    });

    test('testHasInterior', () {
      final shape = S2LaxPolylineShape.create(vertices);
      expect(shape.hasInterior, isFalse);
      expect(shape.containsOrigin, isFalse);
    });

    test('testVerticesAccessor', () {
      final shape = S2LaxPolylineShape.create(vertices);
      expect(shape.vertices.length, equals(3));
      expect(shape.vertex(0), equals(a));
      expect(shape.vertex(1), equals(b));
      expect(shape.vertex(2), equals(c));
    });
  });
}

