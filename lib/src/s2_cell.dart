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

import 'r1_interval.dart';
import 'r2_rect.dart';
import 'r2_vector.dart';
import 's1_interval.dart';
import 's2.dart';
import 's2_cap.dart';
import 's2_cell_id.dart';
import 's2_latlng.dart';
import 's2_latlng_rect.dart';
import 's2_point.dart';
import 's2_projections.dart';
import 's2_region.dart';

/// An S2Cell is an S2Region object that represents a cell.
/// Unlike S2CellIds, it supports efficient containment and intersection tests.
/// However, it is also a more expensive representation.
class S2Cell implements S2Region {
  int _face = 0;
  int _level = 0;
  int _orientation = 0;
  late S2CellId _cellId;
  double _uMin = 0;
  double _uMax = 0;
  double _vMin = 0;
  double _vMax = 0;

  /// Private constructor for internal use.
  S2Cell._();

  /// An S2Cell always corresponds to a particular S2CellId.
  factory S2Cell(S2CellId id) {
    assert(id.isValid);
    final cell = S2Cell._();
    cell._init(id);
    return cell;
  }

  /// Convenience constructor to construct a leaf S2Cell containing the given point.
  factory S2Cell.fromPoint(S2Point p) {
    return S2Cell(S2CellId.fromPoint(p));
  }

  /// Convenience constructor to construct a leaf S2Cell containing the given lat,lng.
  factory S2Cell.fromLatLng(S2LatLng ll) {
    return S2Cell(S2CellId.fromLatLng(ll));
  }

  /// Returns the cell corresponding to the given S2 cube face.
  factory S2Cell.fromFace(int face) {
    return S2Cell(S2CellId.fromFace(face));
  }

  /// Returns the S2CellId of this cell.
  S2CellId get id => _cellId;

  /// Returns the face this cell is located on, in the range 0..5.
  int get face => _face;

  /// Returns the level of this cell, in the range 0..S2CellId.MAX_LEVEL.
  int get level => _level;

  /// Returns the cell orientation, in the range 0..3.
  int get orientation => _orientation;

  /// Returns true if this cell is a leaf-cell, i.e. it has no children.
  bool get isLeaf => _level == S2CellId.maxLevel;

  /// Return the four direct children of this cell in traversal order.
  List<S2Cell> subdivide() {
    assert(!isLeaf);
    final children = <S2Cell>[];
    S2CellId childId = _cellId.childBegin;
    for (int i = 0; i < 4; i++) {
      children.add(S2Cell(childId));
      childId = childId.next;
    }
    return children;
  }

  /// Returns the k-th vertex of the cell (k = 0,1,2,3) in CCW order.
  S2Point getVertex(int k) {
    return getVertexRaw(k).normalize();
  }

  /// Returns the k-th vertex of the cell (k = 0,1,2,3) not normalized.
  S2Point getVertexRaw(int k) {
    k &= 3;
    // Vertices are returned in the order SW, SE, NE, NW.
    return S2Projections.faceUvToXyz(
      _face,
      ((k >> 1) ^ (k & 1)) == 0 ? _uMin : _uMax,
      (k >> 1) == 0 ? _vMin : _vMax,
    );
  }

  /// Returns the inward-facing normal of the k-th edge, normalized.
  S2Point getEdge(int k) {
    return getEdgeRaw(k).normalize();
  }

  /// Returns the inward-facing normal of the k-th edge, not normalized.
  S2Point getEdgeRaw(int k) {
    switch (k & 3) {
      case 0:
        return S2Projections.getVNorm(_face, _vMin); // Bottom
      case 1:
        return S2Projections.getUNorm(_face, _uMax); // Right
      case 2:
        return S2Projections.getVNorm(_face, _vMax).neg(); // Top
      default:
        return S2Projections.getUNorm(_face, _uMin).neg(); // Left
    }
  }

  /// Returns the edge length in (i,j)-space.
  int get sizeIJ => S2CellId.getSizeIJ(_level);

  /// Returns the center of the cell as an S2Point.
  S2Point get center => centerRaw.normalize();

  /// Returns the center of the cell, not normalized.
  S2Point get centerRaw => _cellId.toPointRaw();

  /// Returns the center of the cell in (u,v) coordinates.
  R2Vector get centerUV => _cellId.getCenterUV();

  /// Returns the bounds of this cell in (u,v)-space.
  R2Rect get boundUV {
    return R2Rect(R1Interval(_uMin, _uMax), R1Interval(_vMin, _vMax));
  }

  /// Return the average area in steradians for cells at the given level.
  static double averageAreaAtLevel(int level) {
    return S2Projections.avgArea.getValue(level);
  }

  /// Return the average area of this cell.
  double get averageArea => averageAreaAtLevel(_level);

  /// Return the approximate area of this cell.
  double get approxArea {
    if (_level < 2) return averageArea;

    // First, compute the approximate area when projected perpendicular to its normal
    final v20 = getVertex(2) - getVertex(0);
    final v31 = getVertex(3) - getVertex(1);
    final flatArea = 0.5 * v20.crossProd(v31).norm;

    // Compensate for the curvature of the cell surface
    return flatArea * 2 / (1 + math.sqrt(1 - math.min(S2.m1Pi * flatArea, 1.0)));
  }

  /// Returns the exact area of this cell.
  double get exactArea {
    final v0 = getVertex(0);
    final v1 = getVertex(1);
    final v2 = getVertex(2);
    final v3 = getVertex(3);
    return S2.area(v0, v1, v2) + S2.area(v0, v2, v3);
  }

  // S2Region interface implementation

  @override
  S2Cap get capBound {
    // Use the cell center in (u,v)-space as the cap axis
    final uv = centerUV;
    final center = S2Projections.faceUvToXyz(_face, uv.x, uv.y).normalize();
    var cap = S2Cap.fromAxisHeight(center, 0);
    for (int k = 0; k < 4; k++) {
      cap = cap.addPoint(getVertex(k));
    }
    return cap;
  }

  @override
  S2LatLngRect get rectBound {
    if (_level > 0) {
      // The latitude and longitude extremes are attained at the vertices
      final u = _uMin + _uMax;
      final v = _vMin + _vMax;
      final i = (S2Projections.getUAxis(_face).z == 0 ? (u < 0) : (u > 0)) ? 1 : 0;
      final j = (S2Projections.getVAxis(_face).z == 0 ? (v < 0) : (v > 0)) ? 1 : 0;

      final lat = R1Interval.fromPointPair(
        S2LatLng.latitude(_getPoint(i, j)).radians,
        S2LatLng.latitude(_getPoint(1 - i, 1 - j)).radians,
      );
      final lng = S1Interval.fromPointPair(
        S2LatLng.longitude(_getPoint(i, 1 - j)).radians,
        S2LatLng.longitude(_getPoint(1 - i, j)).radians,
      );

      // Grow the bounds slightly to ensure containment
      return S2LatLngRect(lat, lng)
          .expanded(S2LatLng.fromRadians(2 * S2.dblEpsilon, 2 * S2.dblEpsilon))
          .polarClosure();
    }

    // For face cells, compute the bounding rectangle based on the face
    return _getFaceBound(_face);
  }

  static S2LatLngRect _getFaceBound(int face) {
    final piOver4 = S2.pi / 4;
    switch (face) {
      case 0:
        return S2LatLngRect(
          R1Interval(-piOver4, piOver4),
          S1Interval(-piOver4, piOver4),
        );
      case 1:
        return S2LatLngRect(
          R1Interval(-piOver4, piOver4),
          S1Interval(piOver4, 3 * piOver4),
        );
      case 2:
        return S2LatLngRect(
          R1Interval(math.asin(math.sqrt(1.0 / 3)) - 0.5 * S2.dblEpsilon, S2.piOver2),
          S1Interval.full(),
        );
      case 3:
        return S2LatLngRect(
          R1Interval(-piOver4, piOver4),
          S1Interval(3 * piOver4, -3 * piOver4),
        );
      case 4:
        return S2LatLngRect(
          R1Interval(-piOver4, piOver4),
          S1Interval(-3 * piOver4, -piOver4),
        );
      default:
        return S2LatLngRect(
          R1Interval(-S2.piOver2, -math.asin(math.sqrt(1.0 / 3)) + 0.5 * S2.dblEpsilon),
          S1Interval.full(),
        );
    }
  }

  @override
  void getCellUnionBound(List<S2CellId> results) {
    results.clear();
    results.add(_cellId);
  }

  @override
  bool containsCell(S2Cell cell) {
    return _cellId.contains(cell._cellId);
  }

  @override
  bool containsPoint(S2Point p) {
    // Project point to this face and check if it's within the UV bounds
    final uv = S2Projections.faceXyzToUv(_face, p);
    if (uv == null) return false;

    // Expand the (u,v) bound to ensure that
    // S2Cell(S2CellId.fromPoint(p)).containsPoint(p) is always true
    return uv.x >= (_uMin - S2.dblEpsilon) &&
        uv.x <= (_uMax + S2.dblEpsilon) &&
        uv.y >= (_vMin - S2.dblEpsilon) &&
        uv.y <= (_vMax + S2.dblEpsilon);
  }

  @override
  bool mayIntersect(S2Cell cell) {
    return _cellId.intersects(cell._cellId);
  }

  void _init(S2CellId id) {
    _cellId = id;
    _face = id.face;
    _level = id.level;

    final ijo = id.toIJOrientation();
    _orientation = S2CellId.getOrientation(ijo);
    final i = S2CellId.getI(ijo);
    final j = S2CellId.getJ(ijo);
    final cellSize = id.sizeIJ;

    _uMin = S2Projections.ijToUV(i, cellSize);
    _uMax = S2Projections.ijToUV(i + cellSize, cellSize);
    _vMin = S2Projections.ijToUV(j, cellSize);
    _vMax = S2Projections.ijToUV(j + cellSize, cellSize);
  }

  S2Point _getPoint(int i, int j) {
    return S2Projections.faceUvToXyz(_face, i == 0 ? _uMin : _uMax, j == 0 ? _vMin : _vMax);
  }

  @override
  String toString() => '[$_face, $_level, $_orientation, $_cellId]';

  @override
  bool operator ==(Object other) {
    if (other is S2Cell) {
      return _cellId == other._cellId;
    }
    return false;
  }

  @override
  int get hashCode => _cellId.hashCode;
}

