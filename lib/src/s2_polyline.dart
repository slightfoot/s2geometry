// Copyright 2006 Google Inc.
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

import 's1_angle.dart';
import 's2.dart';
import 's2_cap.dart';
import 's2_cell.dart';
import 's2_cell_id.dart';
import 's2_edge_util.dart';
import 's2_latlng_rect.dart';
import 's2_point.dart';
import 's2_region.dart';

/// An S2Polyline represents a sequence of zero or more vertices connected by
/// straight edges (geodesics). Edges of length 0 and 180 degrees are not
/// allowed, i.e. adjacent vertices should not be identical or antipodal.
///
/// S2Polylines are immutable.
class S2Polyline implements S2Region {
  final List<S2Point> _vertices;

  /// Create a polyline that connects the given vertices.
  S2Polyline(List<S2Point> vertices) : _vertices = List.unmodifiable(vertices);

  /// Copy constructor.
  S2Polyline.from(S2Polyline other) : _vertices = List.unmodifiable(other._vertices);

  /// Returns an unmodifiable view of the vertices of this polyline.
  List<S2Point> get vertices => _vertices;

  /// Returns the number of vertices.
  int get numVertices => _vertices.length;

  /// Returns the vertex at index k.
  S2Point vertex(int k) => _vertices[k];

  /// Return true if the polyline is valid.
  bool isValid() {
    int n = _vertices.length;
    for (int i = 0; i < n; ++i) {
      if (!S2.isUnitLength(_vertices[i])) {
        return false;
      }
    }
    for (int i = 1; i < n; ++i) {
      if (_vertices[i - 1] == _vertices[i] ||
          _vertices[i - 1] == -_vertices[i]) {
        return false;
      }
    }
    return true;
  }

  /// Return the angle corresponding to the total arclength of the polyline.
  S1Angle getArclengthAngle() {
    double lengthSum = 0;
    for (int i = 1; i < numVertices; ++i) {
      lengthSum += vertex(i - 1).angle(vertex(i));
    }
    return S1Angle.radians(lengthSum);
  }

  /// Return the point at the given fraction along the polyline.
  S2Point interpolate(double fraction) {
    if (numVertices == 0) {
      throw StateError('Empty polyline');
    }
    if (fraction <= 0) {
      return vertex(0);
    }

    double lengthSum = 0;
    for (int i = 1; i < numVertices; ++i) {
      lengthSum += vertex(i - 1).angle(vertex(i));
    }
    double target = fraction * lengthSum;
    for (int i = 1; i < numVertices; ++i) {
      double length = vertex(i - 1).angle(vertex(i));
      if (target < length) {
        return S2EdgeUtil.getPointOnLine(vertex(i - 1), vertex(i), S1Angle.radians(target));
      }
      target -= length;
    }
    return vertex(numVertices - 1);
  }

  // S2Region implementation

  @override
  S2Cap get capBound => rectBound.capBound;

  @override
  S2LatLngRect get rectBound {
    final bounder = RectBounder();
    for (int i = 0; i < numVertices; ++i) {
      bounder.addPoint(vertex(i));
    }
    return bounder.bound;
  }

  @override
  bool containsCell(S2Cell cell) => false;

  @override
  bool containsPoint(S2Point point) => false;

  @override
  bool mayIntersect(S2Cell cell) {
    if (numVertices == 0) return false;

    for (int i = 0; i < numVertices; ++i) {
      if (cell.containsPoint(vertex(i))) {
        return true;
      }
    }

    final cellVertices = List<S2Point>.generate(4, (i) => cell.getVertex(i));
    for (int j = 0; j < 4; ++j) {
      final crosser = EdgeCrosser.withEdgeAndVertex(
          cellVertices[j], cellVertices[(j + 1) & 3], vertex(0));
      for (int i = 1; i < numVertices; ++i) {
        if (crosser.robustCrossingFromD(vertex(i)) >= 0) {
          return true;
        }
      }
    }
    return false;
  }

  @override
  void getCellUnionBound(List<S2CellId> results) {
    capBound.getCellUnionBound(results);
  }

  /// Returns the index of the start point of the edge closest to the given point.
  int getNearestEdgeIndex(S2Point point) {
    if (numVertices == 0) {
      throw StateError('Empty polyline');
    }
    if (numVertices == 1) {
      return 0;
    }

    S1Angle minDistance = S1Angle.radians(10);
    int minIndex = -1;

    for (int i = 0; i < numVertices - 1; ++i) {
      S1Angle distanceToSegment = S2EdgeUtil.getDistance(point, vertex(i), vertex(i + 1));
      if (distanceToSegment < minDistance) {
        minDistance = distanceToSegment;
        minIndex = i;
      }
    }
    return minIndex;
  }

  /// Returns the point on the edge at index that is closest to the given point.
  S2Point projectToEdge(S2Point point, int index) {
    if (numVertices == 0) {
      throw StateError('Empty polyline');
    }
    if (numVertices == 1) {
      return vertex(0);
    }
    return S2EdgeUtil.project(point, vertex(index), vertex(index + 1));
  }

  /// Returns the point on this polyline closest to the given point.
  S2Point project(S2Point queryPoint) {
    if (numVertices == 0) {
      throw StateError('Empty polyline');
    }
    if (numVertices == 1) {
      return vertex(0);
    }
    int i = getNearestEdgeIndex(queryPoint);
    return S2EdgeUtil.project(queryPoint, vertex(i), vertex(i + 1));
  }

  /// Returns true if this polyline intersects the given polyline.
  bool intersects(S2Polyline line) {
    if (numVertices <= 0 || line.numVertices <= 0) {
      return false;
    }
    if (!rectBound.intersectsRect(line.rectBound)) {
      return false;
    }
    for (int i = 1; i < numVertices; ++i) {
      final crosser = EdgeCrosser.withEdgeAndVertex(
          vertex(i - 1), vertex(i), line.vertex(0));
      for (int j = 1; j < line.numVertices; ++j) {
        if (crosser.robustCrossingFromD(line.vertex(j)) >= 0) {
          return true;
        }
      }
    }
    return false;
  }

  @override
  bool operator ==(Object other) {
    if (other is! S2Polyline) return false;
    if (numVertices != other.numVertices) return false;
    for (int i = 0; i < numVertices; i++) {
      if (_vertices[i] != other._vertices[i]) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(_vertices);

  @override
  String toString() {
    final buffer = StringBuffer('S2Polyline, $numVertices points. [');
    for (final v in _vertices) {
      buffer.write('${v.toDegreesString()} ');
    }
    buffer.write(']');
    return buffer.toString();
  }

  /// Returns a new S2Polyline with reversed order of vertices.
  S2Polyline reversed() => S2Polyline(_vertices.reversed.toList());
}

