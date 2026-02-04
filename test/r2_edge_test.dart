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
  group('R2Edge', () {
    test('testDefaultConstructor', () {
      final edge = R2Edge();
      
      expect(edge.v0.x, equals(0));
      expect(edge.v0.y, equals(0));
      expect(edge.v1.x, equals(0));
      expect(edge.v1.y, equals(0));
    });

    test('testInit', () {
      final edge = R2Edge();
      final v0 = R2Vector(1.0, 2.0);
      final v1 = R2Vector(3.0, 4.0);
      
      edge.init(v0, v1);
      
      expect(edge.v0.x, equals(1.0));
      expect(edge.v0.y, equals(2.0));
      expect(edge.v1.x, equals(3.0));
      expect(edge.v1.y, equals(4.0));
    });

    test('testInitFromEdge', () {
      final edge1 = R2Edge();
      edge1.init(R2Vector(1.0, 2.0), R2Vector(3.0, 4.0));
      
      final edge2 = R2Edge();
      edge2.initFromEdge(edge1);
      
      expect(edge2.v0.x, equals(1.0));
      expect(edge2.v0.y, equals(2.0));
      expect(edge2.v1.x, equals(3.0));
      expect(edge2.v1.y, equals(4.0));
    });

    test('testIsEqualTo', () {
      final edge1 = R2Edge();
      edge1.init(R2Vector(1.0, 2.0), R2Vector(3.0, 4.0));
      
      final edge2 = R2Edge();
      edge2.init(R2Vector(1.0, 2.0), R2Vector(3.0, 4.0));
      
      final edge3 = R2Edge();
      edge3.init(R2Vector(1.0, 2.0), R2Vector(5.0, 6.0));
      
      expect(edge1.isEqualTo(edge2), isTrue);
      expect(edge1.isEqualTo(edge3), isFalse);
    });

    test('testMutability', () {
      final edge = R2Edge();
      edge.init(R2Vector(1.0, 2.0), R2Vector(3.0, 4.0));
      
      // Modify v0
      edge.v0.x = 10.0;
      edge.v0.y = 20.0;
      
      expect(edge.v0.x, equals(10.0));
      expect(edge.v0.y, equals(20.0));
      
      // Original v1 unchanged
      expect(edge.v1.x, equals(3.0));
      expect(edge.v1.y, equals(4.0));
    });

    test('testEqualsThrows', () {
      final edge1 = R2Edge();
      final edge2 = R2Edge();
      
      expect(() => edge1 == edge2, throwsUnsupportedError);
    });

    test('testHashCodeThrows', () {
      final edge = R2Edge();
      
      expect(() => edge.hashCode, throwsUnsupportedError);
    });

    test('testToString', () {
      final edge = R2Edge();
      edge.init(R2Vector(1.5, 2.5), R2Vector(3.5, 4.5));
      
      expect(edge.toString(), contains('R2Edge'));
      expect(edge.toString(), contains('1.5'));
      expect(edge.toString(), contains('2.5'));
    });

    test('testCopyIndependence', () {
      final v0 = R2Vector(1.0, 2.0);
      final v1 = R2Vector(3.0, 4.0);
      
      final edge = R2Edge();
      edge.init(v0, v1);
      
      // Modifying the original vectors should not affect the edge
      v0.x = 100.0;
      v1.y = 200.0;
      
      expect(edge.v0.x, equals(1.0));
      expect(edge.v1.y, equals(4.0));
    });
  });
}

