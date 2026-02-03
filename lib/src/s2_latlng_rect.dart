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
import 's1_chord_angle.dart';
import 's1_interval.dart';
import 's2.dart';
import 's2_cap.dart';
import 's2_cell.dart';
import 's2_cell_id.dart';
import 's2_latlng.dart';
import 's2_point.dart';
import 's2_region.dart';

/// S2LatLngRect represents a closed latitude-longitude rectangle.
/// It is capable of representing the empty and full rectangles as well as
/// single points.
///
/// Note that the latitude-longitude space is considered to have a cylindrical
/// topology rather than a spherical one.
class S2LatLngRect implements S2Region {
  final R1Interval _lat;
  final S1Interval _lng;

  S2LatLngRect(this._lat, this._lng);

  /// Constructs a rectangle from minimum and maximum latitudes and longitudes.
  factory S2LatLngRect.fromLatLng(S2LatLng lo, S2LatLng hi) {
    return S2LatLngRect(
      R1Interval(lo.latRadians, hi.latRadians),
      S1Interval(lo.lngRadians, hi.lngRadians),
    );
  }

  /// The canonical empty rectangle.
  factory S2LatLngRect.empty() {
    return S2LatLngRect(R1Interval.empty(), S1Interval.empty());
  }

  /// The canonical full rectangle.
  factory S2LatLngRect.full() {
    return S2LatLngRect(fullLat, S1Interval.full());
  }

  /// The full allowable range of latitudes.
  static R1Interval get fullLat => R1Interval(-S2.piOver2, S2.piOver2);

  /// The full allowable range of longitudes.
  static S1Interval get fullLng => S1Interval.full();

  /// Convenience method to construct a rectangle containing a single point.
  factory S2LatLngRect.fromPoint(S2LatLng p) {
    return S2LatLngRect(
      R1Interval(p.latRadians, p.latRadians),
      S1Interval.fromPoint(p.lngRadians),
    );
  }

  /// Convenience method to construct the minimal bounding rectangle
  /// containing the two given normalized points.
  factory S2LatLngRect.fromPointPair(S2LatLng p1, S2LatLng p2) {
    return S2LatLngRect(
      R1Interval.fromPointPair(p1.latRadians, p2.latRadians),
      S1Interval.fromPointPair(p1.lngRadians, p2.lngRadians),
    );
  }

  /// Returns the latitude interval.
  R1Interval get lat => _lat;

  /// Returns the longitude interval.
  S1Interval get lng => _lng;

  /// Returns the low corner of the rectangle.
  S2LatLng get lo => S2LatLng.fromRadians(_lat.lo, _lng.lo);

  /// Returns the high corner of the rectangle.
  S2LatLng get hi => S2LatLng.fromRadians(_lat.hi, _lng.hi);

  /// Returns true if the rectangle is valid.
  bool get isValid {
    return (_lat.lo.abs() <= S2.piOver2 &&
        _lat.hi.abs() <= S2.piOver2 &&
        _lng.isValid &&
        _lat.isEmpty == _lng.isEmpty);
  }

  /// Returns true if the rectangle is empty.
  bool get isEmpty => _lat.isEmpty;

  /// Returns true if the rectangle is full.
  bool get isFull => _lat == fullLat && _lng.isFull;

  /// Returns true if the rectangle is a point.
  bool get isPoint => _lat.lo == _lat.hi && _lng.lo == _lng.hi;

  /// Returns the center of the rectangle.
  S2LatLng get center => S2LatLng.fromRadians(_lat.center, _lng.center);

  /// Returns the size of the rectangle in latitude-longitude space.
  S2LatLng get size => S2LatLng.fromRadians(_lat.length, _lng.length);

  /// Returns one of the four vertices of the rectangle.
  S2LatLng getVertex(int k) {
    switch (k) {
      case 0:
        return lo;
      case 1:
        return S2LatLng.fromRadians(_lat.lo, _lng.hi);
      case 2:
        return hi;
      default:
        return S2LatLng.fromRadians(_lat.hi, _lng.lo);
    }
  }

  /// Returns true if the given point is contained by the rectangle.
  bool containsLatLng(S2LatLng ll) {
    return _lat.containsPoint(ll.latRadians) && _lng.containsPoint(ll.lngRadians);
  }

  /// Returns true if the rectangle contains the given point.
  @override
  bool containsPoint(S2Point p) {
    return containsLatLng(S2LatLng.fromPoint(p));
  }

  /// Returns true if this rectangle contains the given other rectangle.
  bool containsRect(S2LatLngRect other) {
    return _lat.contains(other._lat) && _lng.contains(other._lng);
  }

  /// Returns true if this rectangle intersects the given other rectangle.
  bool intersectsRect(S2LatLngRect other) {
    return _lat.intersects(other._lat) && _lng.intersects(other._lng);
  }

  /// Returns a rectangle expanded by the given margin.
  S2LatLngRect expanded(S2LatLng margin) {
    return S2LatLngRect(
      _lat.expanded(margin.latRadians).intersection(fullLat),
      _lng.expanded(margin.lngRadians),
    );
  }

  /// Returns a new rectangle that includes this rectangle and the given point.
  S2LatLngRect addPoint(S2LatLng ll) {
    return S2LatLngRect(
      _lat.addPoint(ll.latRadians),
      _lng.addPoint(ll.lngRadians),
    );
  }

  /// Returns the smallest rectangle containing the union of this and other.
  S2LatLngRect union(S2LatLngRect other) {
    return S2LatLngRect(_lat.union(other._lat), _lng.union(other._lng));
  }

  /// Returns the intersection of this rectangle and the given rectangle.
  S2LatLngRect intersection(S2LatLngRect other) {
    final intersectLat = _lat.intersection(other._lat);
    final intersectLng = _lng.intersection(other._lng);
    if (intersectLat.isEmpty || intersectLng.isEmpty) {
      return S2LatLngRect.empty();
    }
    return S2LatLngRect(intersectLat, intersectLng);
  }

  /// If the rectangle does not include either pole, return it unmodified.
  /// Otherwise expand the longitude range to full.
  S2LatLngRect polarClosure() {
    if (_lat.lo == -S2.piOver2 || _lat.hi == S2.piOver2) {
      return S2LatLngRect(_lat, S1Interval.full());
    }
    return this;
  }

  @override
  S2Cap get capBound {
    if (isEmpty) return S2Cap.empty();
    // Compute the center and radius of a cap that covers the rectangle

    // Check if the rectangle contains a pole
    if (_lat.lo <= -S2.piOver2 || _lat.hi >= S2.piOver2) {
      // Rectangle contains a pole, use a simple bounding cap
      final centerLat = (_lat.lo + _lat.hi) / 2;
      final centerLng = _lng.center;
      final center = S2LatLng.fromRadians(centerLat, centerLng).toPoint();
      double maxDist = 0.0;
      for (int k = 0; k < 4; k++) {
        maxDist = math.max(maxDist, center.getDistance2(getVertex(k).toPoint()));
      }
      return S2Cap.fromAxisChord(center, S1ChordAngle.fromLength2(maxDist));
    }

    // Find the max angular distance from the center to any vertex
    final centerLat = (_lat.lo + _lat.hi) / 2;
    final centerLng = _lng.center;
    final center = S2LatLng.fromRadians(centerLat, centerLng).toPoint();
    double maxDist = 0.0;
    for (int k = 0; k < 4; k++) {
      maxDist = math.max(maxDist, center.getDistance2(getVertex(k).toPoint()));
    }
    return S2Cap.fromAxisChord(center, S1ChordAngle.fromLength2(maxDist));
  }

  @override
  S2LatLngRect get rectBound => this;

  @override
  void getCellUnionBound(List<S2CellId> results) {
    capBound.getCellUnionBound(results);
  }

  @override
  bool containsCell(S2Cell cell) {
    return containsRect(cell.rectBound);
  }

  @override
  bool mayIntersect(S2Cell cell) {
    return intersectsRect(cell.rectBound);
  }

  @override
  bool operator ==(Object other) {
    if (other is S2LatLngRect) {
      return _lat == other._lat && _lng == other._lng;
    }
    return false;
  }

  @override
  int get hashCode => Object.hash(_lat, _lng);

  @override
  String toString() => '[Lo=$lo, Hi=$hi]';
}
