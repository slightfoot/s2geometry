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
  group('MutableEdge', () {
    test('testDefaultConstructor', () {
      final edge = MutableEdge();
      expect(edge.a, isNull);
      expect(edge.b, isNull);
      expect(edge.start, isNull);
      expect(edge.end, isNull);
    });

    test('testConstructorWithPoints', () {
      final a = S2Point(1, 0, 0);
      final b = S2Point(0, 1, 0);
      final edge = MutableEdge(a, b);
      expect(edge.a, equals(a));
      expect(edge.b, equals(b));
    });

    test('testFactoryOf', () {
      final a = S2Point(1, 0, 0);
      final b = S2Point(0, 1, 0);
      final edge = MutableEdge.of(a, b);
      expect(edge.a, equals(a));
      expect(edge.b, equals(b));
    });

    test('testSet', () {
      final edge = MutableEdge();
      final a = S2Point(1, 0, 0);
      final b = S2Point(0, 1, 0);
      edge.set(a, b);
      expect(edge.a, equals(a));
      expect(edge.b, equals(b));
    });

    test('testReverse', () {
      final a = S2Point(1, 0, 0);
      final b = S2Point(0, 1, 0);
      final edge = MutableEdge(a, b);
      edge.reverse();
      expect(edge.a, equals(b));
      expect(edge.b, equals(a));
    });

    test('testIsDegenerate', () {
      final p = S2Point(1, 0, 0);
      final degenerateEdge = MutableEdge(p, p);
      expect(degenerateEdge.isDegenerate, isTrue);

      final nonDegenerateEdge = MutableEdge(p, S2Point(0, 1, 0));
      expect(nonDegenerateEdge.isDegenerate, isFalse);

      // Null endpoints are not degenerate
      final nullEdge = MutableEdge();
      expect(nullEdge.isDegenerate, isFalse);
    });

    test('testHasEndpoint', () {
      final a = S2Point(1, 0, 0);
      final b = S2Point(0, 1, 0);
      final c = S2Point(0, 0, 1);
      final edge = MutableEdge(a, b);

      expect(edge.hasEndpoint(a), isTrue);
      expect(edge.hasEndpoint(b), isTrue);
      expect(edge.hasEndpoint(c), isFalse);
    });

    test('testIsEqualTo', () {
      final a = S2Point(1, 0, 0);
      final b = S2Point(0, 1, 0);
      final edge1 = MutableEdge(a, b);
      final edge2 = MutableEdge(a, b);
      final edge3 = MutableEdge(b, a);

      expect(edge1.isEqualTo(edge2), isTrue);
      expect(edge1.isEqualTo(edge3), isFalse);
    });

    test('testIsSiblingOf', () {
      final a = S2Point(1, 0, 0);
      final b = S2Point(0, 1, 0);
      final edge1 = MutableEdge(a, b);
      final edge2 = MutableEdge(b, a);
      final edge3 = MutableEdge(a, b);

      expect(edge1.isSiblingOf(edge2), isTrue);
      expect(edge1.isSiblingOf(edge3), isFalse);
    });

    test('testToString', () {
      final a = S2Point(1, 0, 0);
      final b = S2Point(0, 1, 0);
      final edge = MutableEdge(a, b);
      final str = edge.toString();
      expect(str.isNotEmpty, isTrue);
    });
  });

  group('ChainPosition', () {
    test('testDefaultValues', () {
      final pos = ChainPosition();
      expect(pos.chainId, equals(0));
      expect(pos.offset, equals(0));
    });

    test('testSet', () {
      final pos = ChainPosition();
      pos.set(1, 2);
      expect(pos.chainId, equals(1));
      expect(pos.offset, equals(2));
    });

    test('testIsEqualTo', () {
      final pos1 = ChainPosition()..set(1, 2);
      final pos2 = ChainPosition()..set(1, 2);
      final pos3 = ChainPosition()..set(1, 3);

      expect(pos1.isEqualTo(pos2), isTrue);
      expect(pos1.isEqualTo(pos3), isFalse);
    });
  });

  group('ReferencePoint', () {
    test('testConstructor', () {
      final p = S2Point(1, 0, 0);
      final ref = ReferencePoint(p, true);
      expect(ref.point, equals(p));
      expect(ref.contained, isTrue);
    });

    test('testOriginFactory', () {
      final ref = ReferencePoint.origin(true);
      expect(ref.point, equals(S2.origin));
      expect(ref.contained, isTrue);

      final refFalse = ReferencePoint.origin(false);
      expect(refFalse.contained, isFalse);
    });

    test('testEqualsPoint', () {
      final p = S2Point(1, 0, 0);
      final ref = ReferencePoint(p, true);
      expect(ref.equalsPoint(p), isTrue);
      expect(ref.equalsPoint(S2Point(0, 1, 0)), isFalse);
    });

    test('testEquals', () {
      final p = S2Point(1, 0, 0);
      final ref1 = ReferencePoint(p, true);
      final ref2 = ReferencePoint(p, true);
      final ref3 = ReferencePoint(p, false);
      final ref4 = ReferencePoint(S2Point(0, 1, 0), true);

      expect(ref1 == ref2, isTrue);
      expect(ref1 == ref3, isFalse);
      expect(ref1 == ref4, isFalse);
    });

    test('testHashCode', () {
      final p = S2Point(1, 0, 0);
      final ref1 = ReferencePoint(p, true);
      final ref2 = ReferencePoint(p, true);
      expect(ref1.hashCode, equals(ref2.hashCode));
    });
  });
}

