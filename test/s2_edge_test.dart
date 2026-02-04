// Copyright 2011 Google Inc.
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
  group('S2Edge', () {
    test('testConstructor', () {
      final start = S2Point(1, 0, 0);
      final end = S2Point(0, 1, 0);
      final edge = S2Edge(start, end);

      expect(edge.start, equals(start));
      expect(edge.end, equals(end));
    });

    test('testEquals', () {
      final a = S2Edge(S2Point(1, 0, 0), S2Point(0, 1, 0));
      final b = S2Edge(S2Point(1, 0, 0), S2Point(0, 1, 0));
      final c = S2Edge(S2Point(0, 1, 0), S2Point(1, 0, 0));

      expect(a == b, isTrue);
      expect(a == c, isFalse);
      expect(a.hashCode, equals(b.hashCode));
    });

    test('testToString', () {
      final edge = S2Edge(S2Point(1, 0, 0), S2Point(0, 1, 0));
      final str = edge.toString();
      expect(str.contains('Edge'), isTrue);
    });

    // S2Shape interface tests
    test('testNumEdges', () {
      final edge = S2Edge(S2Point(1, 0, 0), S2Point(0, 1, 0));
      expect(edge.numEdges, equals(1));
    });

    test('testGetEdge', () {
      final start = S2Point(1, 0, 0);
      final end = S2Point(0, 1, 0);
      final edge = S2Edge(start, end);

      final result = MutableEdge();
      edge.getEdge(0, result);
      expect(result.a, equals(start));
      expect(result.b, equals(end));
    });

    test('testHasInterior', () {
      final edge = S2Edge(S2Point(1, 0, 0), S2Point(0, 1, 0));
      expect(edge.hasInterior, isFalse);
    });

    test('testContainsOrigin', () {
      final edge = S2Edge(S2Point(1, 0, 0), S2Point(0, 1, 0));
      expect(edge.containsOrigin, isFalse);
    });

    test('testNumChains', () {
      final edge = S2Edge(S2Point(1, 0, 0), S2Point(0, 1, 0));
      expect(edge.numChains, equals(1));
    });

    test('testGetChainStart', () {
      final edge = S2Edge(S2Point(1, 0, 0), S2Point(0, 1, 0));
      expect(edge.getChainStart(0), equals(0));
    });

    test('testGetChainLength', () {
      final edge = S2Edge(S2Point(1, 0, 0), S2Point(0, 1, 0));
      expect(edge.getChainLength(0), equals(1));
    });

    test('testGetChainEdge', () {
      final start = S2Point(1, 0, 0);
      final end = S2Point(0, 1, 0);
      final edge = S2Edge(start, end);

      final result = MutableEdge();
      edge.getChainEdge(0, 0, result);
      expect(result.a, equals(start));
      expect(result.b, equals(end));
    });

    test('testGetChainVertex', () {
      final start = S2Point(1, 0, 0);
      final end = S2Point(0, 1, 0);
      final edge = S2Edge(start, end);

      expect(edge.getChainVertex(0, 0), equals(start));
      expect(edge.getChainVertex(0, 1), equals(end));
    });

    test('testGetChainPosition', () {
      final edge = S2Edge(S2Point(1, 0, 0), S2Point(0, 1, 0));
      final result = ChainPosition();
      edge.getChainPosition(0, result);
      expect(result.chainId, equals(0));
      expect(result.offset, equals(0));
    });

    test('testDimension', () {
      final edge = S2Edge(S2Point(1, 0, 0), S2Point(0, 1, 0));
      expect(edge.dimension, equals(1));
    });

    test('testIsEmpty', () {
      final edge = S2Edge(S2Point(1, 0, 0), S2Point(0, 1, 0));
      expect(edge.isEmpty, isFalse);
    });

    test('testIsFull', () {
      final edge = S2Edge(S2Point(1, 0, 0), S2Point(0, 1, 0));
      expect(edge.isFull, isFalse);
    });
  });
}

