// Copyright 2005 Google Inc.
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

/// Tests for S2TextFormat - text parsing/formatting for S2 geometry objects.
library;

import 'package:test/test.dart';
import 'package:s2geometry/s2geometry.dart';

void main() {
  group('S2TextFormat', () {
    group('makePoint', () {
      test('parses single point', () {
        final point = S2TextFormat.makePointOrDie('0:0');
        expect(point, isNotNull);
        final ll = S2LatLng.fromPoint(point);
        expect(ll.latDegrees, closeTo(0.0, 1e-10));
        expect(ll.lngDegrees, closeTo(0.0, 1e-10));
      });

      test('parses point with decimals', () {
        final point = S2TextFormat.makePointOrDie('37.7749:-122.4194');
        final ll = S2LatLng.fromPoint(point);
        expect(ll.latDegrees, closeTo(37.7749, 1e-4));
        expect(ll.lngDegrees, closeTo(-122.4194, 1e-4));
      });

      test('parses negative coordinates', () {
        final point = S2TextFormat.makePointOrDie('-20:150');
        final ll = S2LatLng.fromPoint(point);
        expect(ll.latDegrees, closeTo(-20.0, 1e-10));
        expect(ll.lngDegrees, closeTo(150.0, 1e-10));
      });

      test('makePoint returns null for invalid input', () {
        expect(S2TextFormat.makePoint(''), isNull);
        expect(S2TextFormat.makePoint('abc'), isNull);
        expect(S2TextFormat.makePoint('1:2:3'), isNull);
        expect(S2TextFormat.makePoint('1:2, 3:4'), isNull);
      });
    });

    group('parseLatLngs', () {
      test('parses empty string', () {
        final latlngs = S2TextFormat.parseLatLngsOrDie('');
        expect(latlngs, isEmpty);
      });

      test('parses single latlng', () {
        final latlngs = S2TextFormat.parseLatLngsOrDie('-20:150');
        expect(latlngs, hasLength(1));
        expect(latlngs[0].latDegrees, closeTo(-20.0, 1e-10));
        expect(latlngs[0].lngDegrees, closeTo(150.0, 1e-10));
      });

      test('parses multiple latlngs', () {
        final latlngs = S2TextFormat.parseLatLngsOrDie('-20:150, -20:151, -19:150');
        expect(latlngs, hasLength(3));
        expect(latlngs[0].latDegrees, closeTo(-20.0, 1e-10));
        expect(latlngs[1].lngDegrees, closeTo(151.0, 1e-10));
        expect(latlngs[2].latDegrees, closeTo(-19.0, 1e-10));
      });
    });

    group('parsePoints', () {
      test('parses points', () {
        final points = S2TextFormat.parsePointsOrDie('0:0, 45:90');
        expect(points, hasLength(2));
        expect(S2LatLng.fromPoint(points[0]).latDegrees, closeTo(0.0, 1e-10));
        expect(S2LatLng.fromPoint(points[1]).latDegrees, closeTo(45.0, 1e-10));
      });
    });

    group('makeLatLng', () {
      test('parses single latlng', () {
        final ll = S2TextFormat.makeLatLngOrDie('37.7749:-122.4194');
        expect(ll.latDegrees, closeTo(37.7749, 1e-4));
        expect(ll.lngDegrees, closeTo(-122.4194, 1e-4));
      });

      test('returns null for multiple points', () {
        expect(S2TextFormat.makeLatLng('1:2, 3:4'), isNull);
      });
    });

    group('makeLatLngRect', () {
      test('creates rect from two points', () {
        final rect = S2TextFormat.makeLatLngRectOrDie('0:0, 10:10');
        expect(rect.lo.latDegrees, closeTo(0.0, 1e-10));
        expect(rect.lo.lngDegrees, closeTo(0.0, 1e-10));
        expect(rect.hi.latDegrees, closeTo(10.0, 1e-10));
        expect(rect.hi.lngDegrees, closeTo(10.0, 1e-10));
      });

      test('returns null for empty string', () {
        expect(S2TextFormat.makeLatLngRect(''), isNull);
      });
    });

    group('makeCellId', () {
      test('parses face', () {
        final cellId = S2TextFormat.makeCellIdOrDie('3/');
        expect(cellId.face, equals(3));
        expect(cellId.level, equals(0));
      });

      test('parses face with children', () {
        final cellId = S2TextFormat.makeCellIdOrDie('4/012');
        expect(cellId.face, equals(4));
        expect(cellId.level, equals(3));
      });

      test('returns null for invalid input', () {
        expect(S2TextFormat.makeCellId(''), isNull);
        expect(S2TextFormat.makeCellId('abc'), isNull);
        expect(S2TextFormat.makeCellId('6/'), isNull); // invalid face
      });
    });

    group('makeCellUnion', () {
      test('parses single cell', () {
        final union = S2TextFormat.makeCellUnionOrDie('1/');
        expect(union.size, equals(1));
        expect(union.cellId(0).face, equals(1));
      });

      test('parses multiple cells', () {
        final union = S2TextFormat.makeCellUnionOrDie('0/, 1/, 2/');
        // Note: normalization may combine cells
        expect(union.size, greaterThanOrEqualTo(1));
      });
    });

    group('makePolyline', () {
      test('parses polyline', () {
        final polyline = S2TextFormat.makePolylineOrDie('0:0, 0:10, 10:10');
        expect(polyline.numVertices, equals(3));
      });

      test('returns null for invalid input', () {
        expect(S2TextFormat.makePolyline('invalid'), isNull);
      });
    });
  });
}

