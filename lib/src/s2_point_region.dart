// Copyright 2017 Google Inc.
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

import 's2_cap.dart';
import 's2_cell.dart';
import 's2_cell_id.dart';
import 's2_latlng.dart';
import 's2_latlng_rect.dart';
import 's2_point.dart';
import 's2_region.dart';

/// An S2PointRegion is a region that contains a single point. It is more
/// expensive than the raw S2Point type and is useful mainly for completeness.
class S2PointRegion implements S2Region, Comparable<S2PointRegion> {
  final S2Point _point;

  /// Creates an S2PointRegion from x, y, z coordinates.
  S2PointRegion.fromCoords(double x, double y, double z)
      : _point = S2Point(x, y, z);

  /// Creates an S2PointRegion from an S2Point.
  S2PointRegion(this._point);

  /// Returns the point.
  S2Point get point => _point;

  /// Returns the x coordinate.
  double get x => _point.x;

  /// Returns the y coordinate.
  double get y => _point.y;

  /// Returns the z coordinate.
  double get z => _point.z;

  @override
  bool operator ==(Object other) {
    if (other is! S2PointRegion) return false;
    return _point == other._point;
  }

  /// Returns true if this point region is less than [other].
  bool lessThan(S2PointRegion other) => _point.lessThan(other._point);

  @override
  int compareTo(S2PointRegion other) {
    return lessThan(other) ? -1 : (this == other ? 0 : 1);
  }

  @override
  String toString() => _point.toString();

  /// Returns the point as a string in degrees.
  String toDegreesString() => _point.toDegreesString();

  @override
  int get hashCode => _point.hashCode;

  // S2Region implementation

  @override
  bool containsCell(S2Cell cell) => false;

  @override
  bool containsPoint(S2Point p) => _point.containsPoint(p);

  @override
  S2Cap get capBound => S2Cap.fromAxisHeight(_point, 0);

  @override
  S2LatLngRect get rectBound {
    final latLng = S2LatLng.fromPoint(_point);
    return S2LatLngRect.fromPoint(latLng);
  }

  @override
  bool mayIntersect(S2Cell cell) => cell.containsPoint(_point);

  @override
  void getCellUnionBound(List<S2CellId> results) {
    capBound.getCellUnionBound(results);
  }
}

