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

import 'dart:math' as math;

import 'package:s2geometry/s2geometry.dart';
import 'package:test/test.dart';

void main() {
  group('S2EdgeVectorShape', () {
    late math.Random random;

    setUp(() {
      random = math.Random(1);
    });

    S2Point getRandomPoint() {
      final u = random.nextDouble() * 2 - 1;
      final theta = random.nextDouble() * 2 * math.pi;
      final r = math.sqrt(1 - u * u);
      return S2Point(r * math.cos(theta), r * math.sin(theta), u);
    }

    test('testEdgeAccess', () {
      final shape = S2EdgeVectorShape();
      const numEdges = 100;
      final edges = <S2Edge>[];
      for (int i = 0; i < numEdges; ++i) {
        final a = getRandomPoint();
        final b = getRandomPoint();
        shape.add(a, b);
        edges.add(S2Edge(a, b));
      }
      expect(shape.numEdges, equals(numEdges));
      final edge = MutableEdge();
      for (int i = 0; i < numEdges; ++i) {
        shape.getEdge(i, edge);
        expect(S2Edge(edge.a!, edge.b!), equals(edges[i]));
      }
    });

    test('testSingletonConstructor', () {
      final a = S2Point(1, 0, 0);
      final b = S2Point(0, 1, 0);
      final shape = S2EdgeVectorShape.single(a, b);
      expect(shape.numEdges, equals(1));
      final edge = MutableEdge();
      shape.getEdge(0, edge);
      expect(edge.a, equals(a));
      expect(edge.b, equals(b));
    });

    test('testEmptyShape', () {
      final shape = S2EdgeVectorShape();
      expect(shape.hasInterior, isFalse);
      expect(shape.numEdges, equals(0));
      expect(shape.numChains, equals(0));
      expect(shape.dimension, equals(1));
    });

    test('testSingleEdgeShape', () {
      final shape = S2EdgeVectorShape.single(
        S2LatLng.fromDegrees(0, 0).toPoint(),
        S2LatLng.fromDegrees(1, 1).toPoint(),
      );
      expect(shape.hasInterior, isFalse);
      expect(shape.numEdges, equals(1));
      expect(shape.numChains, equals(1));
      expect(shape.getChainStart(0), equals(0));
      expect(shape.getChainLength(0), equals(1));
      expect(shape.dimension, equals(1));
    });

    test('testDoubleEdgeShape', () {
      final shape = S2EdgeVectorShape.single(
        S2LatLng.fromDegrees(0, 0).toPoint(),
        S2LatLng.fromDegrees(1, 1).toPoint(),
      );
      shape.add(
        S2LatLng.fromDegrees(2, 2).toPoint(),
        S2LatLng.fromDegrees(3, 3).toPoint(),
      );
      expect(shape.hasInterior, isFalse);
      expect(shape.numEdges, equals(2));
      expect(shape.numChains, equals(2));
      expect(shape.getChainStart(0), equals(0));
      expect(shape.getChainStart(1), equals(1));
      expect(shape.getChainLength(0), equals(1));
      expect(shape.getChainLength(1), equals(1));
      expect(shape.dimension, equals(1));
    });

    test('testGetChainEdge', () {
      final a = S2Point(1, 0, 0);
      final b = S2Point(0, 1, 0);
      final shape = S2EdgeVectorShape.single(a, b);
      final edge = MutableEdge();
      shape.getChainEdge(0, 0, edge);
      expect(edge.a, equals(a));
      expect(edge.b, equals(b));
    });

    test('testGetChainPosition', () {
      final shape = S2EdgeVectorShape();
      shape.add(S2Point(1, 0, 0), S2Point(0, 1, 0));
      shape.add(S2Point(0, 0, 1), S2Point(1, 0, 0));

      final pos = ChainPosition();
      shape.getChainPosition(0, pos);
      expect(pos.chainId, equals(0));
      expect(pos.offset, equals(0));

      shape.getChainPosition(1, pos);
      expect(pos.chainId, equals(1));
      expect(pos.offset, equals(0));
    });

    test('testGetChainVertex', () {
      final a = S2Point(1, 0, 0);
      final b = S2Point(0, 1, 0);
      final shape = S2EdgeVectorShape.single(a, b);
      expect(shape.getChainVertex(0, 0), equals(a));
      expect(shape.getChainVertex(0, 1), equals(b));
    });

    test('testAddDegenerate', () {
      final shape = S2EdgeVectorShape();
      final p = S2Point(1, 0, 0);
      shape.addDegenerate(p);
      expect(shape.numEdges, equals(1));
      final edge = MutableEdge();
      shape.getEdge(0, edge);
      expect(edge.a, equals(p));
      expect(edge.b, equals(p));
    });

    test('testDegenerateNotAllowedInAdd', () {
      final shape = S2EdgeVectorShape();
      final p = S2Point(1, 0, 0);
      expect(() => shape.add(p, p), throwsArgumentError);
    });

    test('testIndexOperator', () {
      final a = S2Point(1, 0, 0);
      final b = S2Point(0, 1, 0);
      final shape = S2EdgeVectorShape.single(a, b);
      expect(shape[0], equals(S2Edge(a, b)));
    });

    test('testLength', () {
      final shape = S2EdgeVectorShape();
      expect(shape.length, equals(0));
      shape.add(S2Point(1, 0, 0), S2Point(0, 1, 0));
      expect(shape.length, equals(1));
      shape.add(S2Point(0, 0, 1), S2Point(1, 0, 0));
      expect(shape.length, equals(2));
    });
  });
}

