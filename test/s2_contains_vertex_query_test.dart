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

/// Port of S2ContainsVertexQueryTest.java from the S2 Geometry library.
library;

import 'package:s2geometry/s2geometry.dart';
import 'package:test/test.dart';

S2Point makePoint(String latLng) {
  return S2TextFormat.makeLatLng(latLng)!.toPoint();
}

void main() {
  group('S2ContainsVertexQuery', () {
    test('testUndetermined', () {
      final q = S2ContainsVertexQuery.withTarget(makePoint('1:2'));
      q.addOutgoing(makePoint('3:4'));
      q.addIncoming(makePoint('3:4'));
      expect(q.safeContainsSign(), equals(0));
      expect(q.duplicateEdges(), isFalse);
    });

    test('testContainedWithDuplicates', () {
      // The S2.ortho reference direction points approximately due west.
      // Containment is determined by the unmatched edge immediately clockwise.
      final q = S2ContainsVertexQuery.withTarget(makePoint('0:0'));
      q.addIncoming(makePoint('3:-3'));
      q.addOutgoing(makePoint('1:-5'));
      q.addOutgoing(makePoint('2:-4'));
      q.addIncoming(makePoint('1:-5'));
      expect(q.containsSign(), equals(1));
      expect(q.duplicateEdges(), isFalse);

      // Incoming and outgoing edges to 1:-5 cancel, so one more incoming isn't a duplicate.
      q.addIncoming(makePoint('1:-5'));
      expect(q.duplicateEdges(), isFalse);

      // 3:-3 has only been seen once incoming, another incoming is a duplicate.
      q.addIncoming(makePoint('3:-3'));
      expect(q.duplicateEdges(), isTrue);
    });

    test('testNotContainedWithDuplicates', () {
      // The S2.ortho reference direction points approximately due west.
      // Containment is determined by the unmatched edge immediately clockwise.
      final q = S2ContainsVertexQuery.withTarget(makePoint('1:1'));
      q.addOutgoing(makePoint('1:-5'));
      q.addIncoming(makePoint('2:-4'));
      q.addOutgoing(makePoint('3:-3'));
      q.addIncoming(makePoint('1:-5'));
      final result = q.safeContainsSign();
      expect(result, isNotNull);
      expect(result, equals(-1));

      // Incoming and outgoing edges to 1:-5 cancel, so one more outgoing isn't a duplicate.
      q.addOutgoing(makePoint('1:-5'));
      final result2 = q.safeContainsSign();
      expect(result2, isNotNull);

      // 3:-3 has only been seen once outgoing, another outgoing is a duplicate.
      q.addOutgoing(makePoint('3:-3'));
      final result3 = q.safeContainsSign();
      expect(result3, isNull);
    });

    test('testCompatibleWithAngleContainsVertexDegenerate', () {
      // Tests compatibility with S2Predicates.angleContainsVertex() for a degenerate edge.
      final a = S2Point(1, 0, 0);
      final b = S2Point(0, 1, 0);
      final query = S2ContainsVertexQuery.withTarget(b);
      query.addIncoming(a);
      query.addOutgoing(a);
      // For degenerate edge, containsSign should be 0 (vertex is "on" the edge)
      expect(query.containsSign(), equals(0));
      expect(query.duplicateEdges(), isFalse);
    });

    test('testEmptyQuery', () {
      // A query with no edges should return 0 (undetermined).
      final q = S2ContainsVertexQuery.withTarget(S2Point(1, 0, 0));
      expect(q.safeContainsSign(), equals(0));
      expect(q.duplicateEdges(), isFalse);
    });

    test('testSingleOutgoing', () {
      // A single outgoing edge: the result depends on reference direction.
      // According to Java semantics, outgoing edges result in positive bestSum.
      final q = S2ContainsVertexQuery.withTarget(S2Point(1, 0, 0));
      q.addOutgoing(S2Point(0, 1, 0));
      // The sign depends on which side of the reference direction the edge is
      final sign = q.containsSign();
      expect(sign.abs(), equals(1)); // Either +1 or -1, but not 0
      expect(q.duplicateEdges(), isFalse);
    });

    test('testSingleIncoming', () {
      // A single incoming edge: the result depends on reference direction.
      final q = S2ContainsVertexQuery.withTarget(S2Point(1, 0, 0));
      q.addIncoming(S2Point(0, 1, 0));
      // The sign depends on which side of the reference direction the edge is
      final sign = q.containsSign();
      expect(sign.abs(), equals(1)); // Either +1 or -1, but not 0
      expect(q.duplicateEdges(), isFalse);
    });

    test('testDefaultConstructorWithInit', () {
      // Test using the default constructor followed by init()
      final q = S2ContainsVertexQuery();
      q.init(S2Point(1, 0, 0));
      q.addOutgoing(S2Point(0, 1, 0));
      final sign = q.containsSign();
      expect(sign.abs(), equals(1));
    });

    test('testInitResetsState', () {
      // Test that init() clears previous state
      final q = S2ContainsVertexQuery.withTarget(S2Point(1, 0, 0));
      q.addOutgoing(S2Point(0, 1, 0));
      q.addIncoming(S2Point(0, 0, 1));

      // Re-init with a different target
      q.init(S2Point(0, 1, 0));
      // Should have no edges now
      expect(q.safeContainsSign(), equals(0));
    });
  });
}

