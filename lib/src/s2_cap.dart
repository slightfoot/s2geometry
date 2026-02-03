// Copyright 2005 Google Inc. All Rights Reserved.
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

import 's1_angle.dart';
import 's1_chord_angle.dart';
import 's2.dart';
import 's2_cell.dart';
import 's2_cell_id.dart';
import 's2_latlng_rect.dart';
import 's2_point.dart';
import 's2_projections.dart';
import 's2_region.dart';

/// An S2Cap represents a disc-shaped region defined by a center and radius.
/// Technically this shape is called a "spherical cap" (rather than disc)
/// because it is not planar; the cap represents a portion of the sphere that
/// has been cut off by a plane.
///
/// For containment purposes, the cap is a closed set, i.e. it contains its
/// boundary. The radius of the cap is measured along the surface of the sphere.
class S2Cap implements S2Region {
  final S2Point _axis;
  final S1ChordAngle _radius;

  S2Cap._(this._axis, this._radius);

  /// Creates an S2Cap where the radius is expressed as an S1ChordAngle.
  factory S2Cap.fromAxisChord(S2Point center, S1ChordAngle radius) {
    return S2Cap._(center, radius);
  }

  /// Creates an S2Cap given its axis and the cap height.
  factory S2Cap.fromAxisHeight(S2Point axis, double height) {
    return S2Cap._(axis, S1ChordAngle.fromLength2(2 * height));
  }

  /// Creates an S2Cap given its axis and the cap opening angle.
  factory S2Cap.fromAxisAngle(S2Point axis, S1Angle angle) {
    return S2Cap.fromAxisChord(
      axis,
      S1ChordAngle.fromS1Angle(S1Angle.radians(math.min(angle.radians, math.pi))),
    );
  }

  /// Creates an S2Cap given its axis and its area in steradians.
  factory S2Cap.fromAxisArea(S2Point axis, double area) {
    return S2Cap._(axis, S1ChordAngle.fromLength2(area / math.pi));
  }

  /// Returns an empty cap, i.e. a cap that contains no points.
  factory S2Cap.empty() {
    return S2Cap._(S2Point.xPos, S1ChordAngle.negative);
  }

  /// Returns a full cap, i.e. a cap that contains all points.
  factory S2Cap.full() {
    return S2Cap._(S2Point.xPos, S1ChordAngle.straight);
  }

  /// Returns the normalized point which is the center of the cap.
  S2Point get axis => _axis;

  /// Returns the radius of the cap as a S1ChordAngle.
  S1ChordAngle get radius => _radius;

  /// Returns the height of the cap.
  double get height => 0.5 * _radius.length2;

  /// Returns the area of the cap on the surface of the unit sphere.
  double get area => 2 * math.pi * math.max(0.0, height);

  /// Returns the cap radius as an S1Angle.
  S1Angle get angle => _radius.toAngle();

  /// Returns true if the axis is unit length, and the angle is less than Pi.
  bool get isValid => S2.isUnitLength(_axis) && _radius.length2 <= 4;

  /// Returns true if the cap is empty, i.e. it contains no points.
  bool get isEmpty => _radius.isNegative;

  /// Returns true if the cap is full, i.e. it contains all points.
  bool get isFull => _radius == S1ChordAngle.straight;

  /// Returns the complement of the interior of the cap.
  S2Cap get complement {
    if (isFull) return S2Cap.empty();
    if (isEmpty) return S2Cap.full();
    return S2Cap.fromAxisChord(
      _axis.neg(),
      S1ChordAngle.fromLength2(4 - _radius.length2),
    );
  }

  /// Returns true if this cap contains the given point.
  bool containsPoint(S2Point p) {
    return S1ChordAngle.fromPoints(_axis, p).compareTo(_radius) <= 0;
  }

  /// Returns true if this cap contains the given other cap.
  bool containsCap(S2Cap other) {
    if (isFull || other.isEmpty) return true;
    final axialDistance = S1ChordAngle.fromPoints(_axis, other._axis);
    return _radius.compareTo(axialDistance + other._radius) >= 0;
  }

  /// Returns true if this cap intersects the given other cap.
  bool intersectsCap(S2Cap other) {
    if (isEmpty || other.isEmpty) return false;
    final axialDistance = S1ChordAngle.fromPoints(_axis, other._axis);
    return (_radius + other._radius).greaterOrEquals(axialDistance);
  }

  /// Returns a new S2Cap that includes the given point.
  S2Cap addPoint(S2Point p) {
    if (isEmpty) {
      return S2Cap._(_axis, S1ChordAngle.zero);
    }
    return S2Cap._(
      _axis,
      S1ChordAngle.fromLength2(math.max(_radius.length2, _axis.getDistance2(p))),
    );
  }

  /// Returns a new S2Cap expanded by the given distance.
  S2Cap expanded(S1Angle distance) {
    if (isEmpty) return S2Cap.empty();
    return S2Cap._(_axis, _radius + S1ChordAngle.fromS1Angle(distance));
  }

  @override
  S2Cap get capBound => this;

  @override
  S2LatLngRect get rectBound {
    if (isEmpty) return S2LatLngRect.empty();
    if (isFull) return S2LatLngRect.full();
    // Simplified implementation - compute based on axis and angle
    // Full implementation would need more careful handling
    throw UnimplementedError('S2Cap.rectBound not yet implemented');
  }

  /// Computes a covering of the S2Cap.
  @override
  void getCellUnionBound(List<S2CellId> results) {
    results.clear();
    // Find the maximum level such that the cap contains at most one cell vertex
    final level = S2Projections.minWidth.getMaxLevel(angle.radians) - 1;
    if (level < 0) {
      // More than three face cells are required
      results.addAll(S2CellId.faceCells);
    } else {
      // The covering consists of the 4 cells at the given level that share
      // the cell vertex that is closest to the cap center.
      S2CellId.fromPoint(_axis).getVertexNeighbors(level, results);
    }
  }

  @override
  bool containsCell(S2Cell cell) {
    // If the cap does not contain all cell vertices, return false
    final vertices = <S2Point>[];
    for (int k = 0; k < 4; k++) {
      vertices.add(cell.getVertex(k));
      if (!containsPoint(vertices[k])) {
        return false;
      }
    }
    // Return true if the complement of the cap does not intersect the cell
    return !complement._intersectsCell(cell, vertices);
  }

  @override
  bool mayIntersect(S2Cell cell) {
    // If the cap contains any cell vertex, return true
    final vertices = <S2Point>[];
    for (int k = 0; k < 4; k++) {
      vertices.add(cell.getVertex(k));
      if (containsPoint(vertices[k])) {
        return true;
      }
    }
    return _intersectsCell(cell, vertices);
  }

  bool _intersectsCell(S2Cell cell, List<S2Point> vertices) {
    // If the cap is a hemisphere or larger, the cell and the complement
    // of the cap are both convex
    if (_radius.compareTo(S1ChordAngle.right) >= 0) {
      return false;
    }
    if (isEmpty) return false;

    // Optimization: return true if the cell contains the cap axis
    if (cell.containsPoint(_axis)) {
      return true;
    }

    // Check if cap intersects the interior of some edge
    final sin2Angle = S1ChordAngle.sin2(_radius);
    for (int k = 0; k < 4; k++) {
      final edge = cell.getEdgeRaw(k);
      final dot = _axis.dotProd(edge);
      if (dot > 0) continue;
      if (dot * dot > sin2Angle * edge.norm2()) {
        return false;
      }
      final dir = edge.crossProd(_axis);
      if (dir.dotProd(vertices[k]) < 0 && dir.dotProd(vertices[(k + 1) & 3]) > 0) {
        return true;
      }
    }
    return false;
  }

  @override
  bool operator ==(Object other) {
    if (other is S2Cap) {
      return (_axis == other._axis && _radius == other._radius) ||
          (isEmpty && other.isEmpty) ||
          (isFull && other.isFull);
    }
    return false;
  }

  @override
  int get hashCode {
    if (isFull) return 17;
    if (isEmpty) return 37;
    return Object.hash(_axis, _radius);
  }

  @override
  String toString() => '[Point = $_axis Radius = $_radius]';
}

