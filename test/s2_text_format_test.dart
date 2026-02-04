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

    group('toString methods', () {
      test('pointToString', () {
        final point = S2LatLng.fromDegrees(37.7749, -122.4194).toPoint();
        final str = S2TextFormat.pointToString(point);
        expect(str, contains('37.77'));
        expect(str, contains('-122.41'));
      });

      test('latLngToString', () {
        final ll = S2LatLng.fromDegrees(45.0, 90.0);
        final str = S2TextFormat.latLngToString(ll);
        expect(str, contains('45'));
        expect(str, contains('90'));
      });

      test('latLngRectToString', () {
        final rect = S2LatLngRect.fromPointPair(
          S2LatLng.fromDegrees(0, 0),
          S2LatLng.fromDegrees(10, 10),
        );
        final str = S2TextFormat.latLngRectToString(rect);
        expect(str, contains('0'));
        expect(str, contains('10'));
      });

      test('cellIdToString', () {
        final cellId = S2CellId.fromFace(3);
        final str = S2TextFormat.cellIdToString(cellId);
        expect(str, isNotEmpty);
      });

      test('cellUnionToString', () {
        final union = S2CellUnion.fromCellIds([
          S2CellId.fromFace(0),
          S2CellId.fromFace(1),
        ]);
        final str = S2TextFormat.cellUnionToString(union);
        expect(str, contains('0/'));
        expect(str, contains('1/'));
      });

      test('polylineToString', () {
        final polyline = S2Polyline([
          S2LatLng.fromDegrees(0, 0).toPoint(),
          S2LatLng.fromDegrees(10, 10).toPoint(),
        ]);
        final str = S2TextFormat.polylineToString(polyline);
        expect(str, contains('0'));
        expect(str, contains('10'));
      });

      test('s2PointsToString', () {
        final points = [
          S2LatLng.fromDegrees(0, 0).toPoint(),
          S2LatLng.fromDegrees(45, 90).toPoint(),
        ];
        final str = S2TextFormat.s2PointsToString(points);
        expect(str, contains('0'));
        // May be 44.999... due to floating point
        expect(str, anyOf(contains('45'), contains('44.99')));
      });

      test('s2LatLngsToString', () {
        final latlngs = [
          S2LatLng.fromDegrees(0, 0),
          S2LatLng.fromDegrees(45, 90),
        ];
        final str = S2TextFormat.s2LatLngsToString(latlngs);
        expect(str, contains('0'));
        expect(str, contains('45'));
      });
    });

    group('additional parsing', () {
      test('makePointsOrDie with pipe separator', () {
        final points = S2TextFormat.makePointsOrDie('0:0|45:90');
        expect(points, hasLength(2));
      });

      test('makeEdgesOrDie', () {
        final edges = S2TextFormat.makeEdgesOrDie('0:0, 10:10; 20:20, 30:30');
        expect(edges, hasLength(2));
        expect(edges[0].start, isNotNull);
        expect(edges[0].end, isNotNull);
      });

      test('makePolylinesOrDie with pipe separator', () {
        final polylines = S2TextFormat.makePolylinesOrDie('0:0, 10:10|20:20, 30:30');
        expect(polylines, hasLength(2));
      });

      test('parseVertices', () {
        final vertices = <S2Point>[];
        final rect = S2TextFormat.parseVertices('0:0, 10:10', vertices);
        expect(vertices, hasLength(2));
        expect(rect.isEmpty, isFalse);
      });

      test('snapPointToLevel', () {
        final point = S2LatLng.fromDegrees(37.7749, -122.4194).toPoint();
        final snapped = S2TextFormat.snapPointToLevel(point, 10);
        expect(snapped, isNotNull);
        // Snapped point should be close to original
        expect(point.angle(snapped), lessThan(0.01));
      });

      test('snapPointsToLevel', () {
        final points = [
          S2LatLng.fromDegrees(0, 0).toPoint(),
          S2LatLng.fromDegrees(45, 90).toPoint(),
        ];
        final snapped = S2TextFormat.snapPointsToLevel(points, 10);
        expect(snapped, hasLength(2));
      });

      test('parsePoints with level', () {
        final points = S2TextFormat.parsePoints('0:0, 45:90', 10);
        expect(points, hasLength(2));
      });
    });

    group('error handling', () {
      test('parseLatLngsOrDie throws on invalid', () {
        expect(() => S2TextFormat.parseLatLngsOrDie('invalid:input'),
            throwsArgumentError);
      });

      test('parsePointsOrDie throws on invalid', () {
        expect(() => S2TextFormat.parsePointsOrDie('invalid'),
            throwsArgumentError);
      });

      test('makeLatLngOrDie throws on invalid', () {
        expect(() => S2TextFormat.makeLatLngOrDie('invalid'),
            throwsArgumentError);
      });

      test('makeLatLngRectOrDie throws on invalid', () {
        expect(() => S2TextFormat.makeLatLngRectOrDie('invalid'),
            throwsArgumentError);
      });

      test('makeCellIdOrDie throws on invalid', () {
        expect(() => S2TextFormat.makeCellIdOrDie('invalid'),
            throwsArgumentError);
      });

      test('makeCellUnionOrDie throws on invalid', () {
        expect(() => S2TextFormat.makeCellUnionOrDie('invalid'),
            throwsArgumentError);
      });

      test('makePolylineOrDie throws on invalid', () {
        expect(() => S2TextFormat.makePolylineOrDie('invalid'),
            throwsArgumentError);
      });

      test('makeEdgesOrDie throws on wrong size', () {
        expect(() => S2TextFormat.makeEdgesOrDie('0:0'),
            throwsArgumentError);
      });

      test('makePointOrDie throws on invalid', () {
        expect(() => S2TextFormat.makePointOrDie('invalid'),
            throwsArgumentError);
      });

      test('makeCellId returns null for invalid child character', () {
        // Test invalid child digit (must be 0-3)
        final cellId = S2TextFormat.makeCellId('0/45');
        expect(cellId, isNull);
      });
    });

    group('additional toString methods', () {
      test('cellUnionToString with children', () {
        // Test _cellIdToDebugString via cellUnionToString for cells with children
        final cellId = S2CellId.fromFace(2).child(0).child(1).child(2);
        final union = S2CellUnion.fromCellIds([cellId]);
        final str = S2TextFormat.cellUnionToString(union);
        expect(str, equals('2/012'));
      });

      test('polylinesToString', () {
        final polyline1 = S2Polyline([
          S2LatLng.fromDegrees(0, 0).toPoint(),
          S2LatLng.fromDegrees(10, 10).toPoint(),
        ]);
        final polyline2 = S2Polyline([
          S2LatLng.fromDegrees(20, 20).toPoint(),
          S2LatLng.fromDegrees(30, 30).toPoint(),
        ]);
        final str = S2TextFormat.polylinesToString([polyline1, polyline2]);
        expect(str, contains('|'));
      });

      test('polylinesToString single polyline', () {
        final polyline = S2Polyline([
          S2LatLng.fromDegrees(0, 0).toPoint(),
          S2LatLng.fromDegrees(10, 10).toPoint(),
        ]);
        final str = S2TextFormat.polylinesToString([polyline]);
        expect(str, isNotEmpty);
        expect(str, isNot(contains('|'))); // No separator for single polyline
      });
    });
  });
}

