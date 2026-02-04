// Copyright 2021 Google Inc.
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
  const double epsilon = 1.0e-8;

  group('S2ChainInterpolationQuery', () {
    test('testS1AngleQuerySimplePolylines', () {
      // Set up the test inputs.
      const double latitudeB = 1.0;
      const double latitudeC = 2.5;
      const double totalLengthABC = latitudeC;

      final a = S2LatLng.fromDegrees(0, 0).toPoint();
      final b = S2LatLng.fromDegrees(latitudeB, 0).toPoint();
      final c = S2LatLng.fromDegrees(latitudeC, 0).toPoint();

      final emptyShape = S2LaxPolylineShape.empty;
      final shapeAC = S2LaxPolylineShape.create([a, c]);
      final shapeABC = S2LaxPolylineShape.create([a, b, c]);
      final shapeBB = S2LaxPolylineShape.create([b, b]);
      final polylineCC = S2Polyline([c]); // Single point polyline

      final queryEmpty = S2ChainInterpolationQuery(emptyShape);
      final queryAC = S2ChainInterpolationQuery(shapeAC);
      final queryABC = S2ChainInterpolationQuery(shapeABC);
      final queryBB = S2ChainInterpolationQuery(shapeBB);
      final queryCC = S2ChainInterpolationQuery(S2LaxPolylineShape.fromPolyline(polylineCC));

      final distances = <double>[
        -1.0, 0.0, 1.0e-8, latitudeB / 2, latitudeB - 1.0e-7, latitudeB,
        latitudeB + 1.0e-5, latitudeB + 0.5, latitudeC - 10.0e-7,
        latitudeC, latitudeC + 10.0e-16, 1.0e6,
      ];

      // Run the tests.
      final lengthEmpty = queryEmpty.getLength().degrees;
      final lengthABC = queryABC.getLength().degrees;
      final lengthAC = queryAC.getLength().degrees;
      final lengthBB = queryBB.getLength().degrees;
      final lengthCC = queryCC.getLength().degrees;

      final acResultAtInfinity = queryAC.findPoint(S1Angle.infinity);
      final acPointAtInfinity = queryAC.resultPoint;

      bool emptyQueryResult = false;
      for (final distance in distances) {
        final totalFraction = distance / totalLengthABC;
        emptyQueryResult = emptyQueryResult || queryEmpty.findPointAtFraction(totalFraction);
      }

      // Check the test results.
      expect(emptyQueryResult, isFalse);
      expect(acResultAtInfinity, isTrue);

      expect(lengthEmpty, lessThanOrEqualTo(epsilon));
      expect((totalLengthABC - lengthAC).abs(), lessThanOrEqualTo(epsilon));
      expect((totalLengthABC - lengthABC).abs(), lessThanOrEqualTo(epsilon));
      expect(lengthBB, lessThanOrEqualTo(epsilon));
      expect(lengthCC, lessThanOrEqualTo(epsilon));

      expect(S1Angle.fromPoints(acPointAtInfinity, c).degrees, lessThanOrEqualTo(epsilon));
    });

    test('testS2ParametricQueryDistance', () {
      final distances = <double>[
        -1.0, -1.0e-8, 0.0, 1.0e-8, 0.2, 0.5, 1.0 - 1.0e-8, 1.0, 1.0 + 1.0e-8,
        1.2, 1.2, 1.2 + 1.0e-10, 1.5, 1.999999, 2.0, 2.00000001, 1.0e6,
      ];

      final vertices = S2TextFormat.parsePointsOrDie(
        '0:0, 0:0, 1.0e-7:0, 0.1:0, 0.2:0, 0.2:0, 0.6:0, 0.999999:0, 0.999999:0, '
        '1:0, 1:0, 1.000001:0, 1.000001:0, 1.1:0, 1.2:0, 1.2000001:0, 1.7:0, '
        '1.99999999:0, 2:0',
      );

      final totalLength = S1Angle.fromPoints(vertices.first, vertices.last).degrees;

      final shape = S2LaxPolylineShape.create(vertices);
      final query = S2ChainInterpolationQuery(shape);

      // Run the tests.
      final length = query.getLength().degrees;
      expect((totalLength - length).abs(), lessThanOrEqualTo(epsilon));

      for (final d in distances) {
        final findResult = query.findPoint(S1Angle.degrees(d));
        expect(findResult, isTrue);

        final lat = S2LatLng.fromPoint(query.resultPoint).lat.degrees;
        final edgeId = query.resultEdgeId;
        final distance = query.resultDistance;

        if (d < 0) {
          expect(lat.abs(), lessThanOrEqualTo(epsilon));
          expect(edgeId, equals(0));
          expect(distance.degrees.abs(), lessThanOrEqualTo(epsilon));
        } else if (d > 2) {
          expect((2 - lat).abs(), lessThanOrEqualTo(epsilon));
          expect(edgeId, equals(shape.numEdges - 1));
          expect((distance.degrees - totalLength).abs(), lessThanOrEqualTo(epsilon));
        } else {
          expect((d - lat).abs(), lessThanOrEqualTo(epsilon));
          expect(edgeId, greaterThanOrEqualTo(0));
          expect(edgeId, lessThanOrEqualTo(shape.numEdges));
          final edge = MutableEdge();
          shape.getEdge(edgeId, edge);
          expect(lat, greaterThanOrEqualTo(S2LatLng.fromPoint(edge.a!).lat.degrees - epsilon));
          expect(lat, lessThanOrEqualTo(S2LatLng.fromPoint(edge.b!).lat.degrees + epsilon));
          expect((d - distance.degrees).abs(), lessThanOrEqualTo(epsilon));
        }
      }
    });

    test('testGetLengthAtEdgeEmpty', () {
      final shape = S2LaxPolylineShape.empty;
      final query = S2ChainInterpolationQuery(shape);
      expect(query.getLengthAtEdgeEnd(0), equals(S1Angle.zero));
    });

    test('testGetLengthAtEdgePolyline', () {
      final vertex0 = S2LatLng.fromDegrees(0.0, 0.0).toPoint();
      final vertex1 = S2LatLng.fromDegrees(0.0, 1.0).toPoint();
      final vertex2 = S2LatLng.fromDegrees(0.0, 3.0).toPoint();
      final vertex3 = S2LatLng.fromDegrees(0.0, 6.0).toPoint();

      final shape = S2LaxPolylineShape.create([vertex0, vertex1, vertex2, vertex3]);
      final query = S2ChainInterpolationQuery(shape);

      expect((query.getLength().degrees - 6.0).abs(), lessThanOrEqualTo(0.01));
      expect(query.getLengthAtEdgeEnd(-100), equals(S1Angle.infinity));
      expect((query.getLengthAtEdgeEnd(0).degrees - 1.0).abs(), lessThanOrEqualTo(0.01));
      expect((query.getLengthAtEdgeEnd(1).degrees - 3.0).abs(), lessThanOrEqualTo(0.01));
      expect((query.getLengthAtEdgeEnd(2).degrees - 6.0).abs(), lessThanOrEqualTo(0.01));
      expect(query.getLengthAtEdgeEnd(100), equals(S1Angle.infinity));
    });

    test('testSlice', () {
      final emptyQuery = S2ChainInterpolationQuery(S2LaxPolylineShape.empty);
      expect(emptyQuery.slice(0, 1), isEmpty);

      final polyline = S2TextFormat.makePolylineOrDie('0:0, 0:1, 0:2');
      final shape = S2LaxPolylineShape.fromPolyline(polyline);
      final query = S2ChainInterpolationQuery(shape);

      // Test full slice
      var points = query.slice(0, 1);
      expect(points.length, equals(3));

      // Test half slice
      points = query.slice(0, 0.5);
      expect(points.length, equals(2));

      // Test reverse slice
      points = query.slice(1, 0.5);
      expect(points.length, equals(2));

      // Test partial slice
      points = query.slice(0.25, 0.75);
      expect(points.length, equals(3));
    });
  });
}

