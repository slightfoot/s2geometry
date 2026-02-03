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

import 'platform.dart';
import 's1_angle.dart';
import 's2_point.dart';
import 's2.dart';

/// An immutable representation of a point on the unit sphere, as a pair of
/// latitude-longitude coordinates.
class S2LatLng {
  /// The center point of the lat/lng coordinate system.
  static final S2LatLng center = S2LatLng.fromRadians(0.0, 0.0);

  final double _latRadians;
  final double _lngRadians;

  /// Returns a new S2LatLng specified in radians.
  S2LatLng.fromRadians(this._latRadians, this._lngRadians);

  /// Returns a new S2LatLng converted from degrees.
  factory S2LatLng.fromDegrees(double latDegrees, double lngDegrees) {
    return S2LatLng.fromRadians(
      latDegrees * (math.pi / 180.0),
      lngDegrees * (math.pi / 180.0),
    );
  }

  /// Returns a new S2LatLng converted from tens of microdegrees.
  factory S2LatLng.fromE5(int latE5, int lngE5) {
    return S2LatLng(S1Angle.e5(latE5), S1Angle.e5(lngE5));
  }

  /// Returns a new S2LatLng converted from microdegrees.
  factory S2LatLng.fromE6(int latE6, int lngE6) {
    return S2LatLng(S1Angle.e6(latE6), S1Angle.e6(lngE6));
  }

  /// Returns a new S2LatLng converted from tenths of a microdegree.
  factory S2LatLng.fromE7(int latE7, int lngE7) {
    return S2LatLng(S1Angle.e7(latE7), S1Angle.e7(lngE7));
  }

  /// Returns a new S2LatLng converted from an S2Point.
  factory S2LatLng.fromPoint(S2Point p) {
    return S2LatLng.fromRadians(
      math.atan2(p.z + 0.0, math.sqrt(p.x * p.x + p.y * p.y)),
      math.atan2(p.y + 0.0, p.x + 0.0),
    );
  }

  /// Constructor from S2Point (Java compatibility: new S2LatLng(S2Point p)).
  factory S2LatLng.point(S2Point p) = S2LatLng.fromPoint;

  /// Basic constructor from S1Angle values.
  S2LatLng(S1Angle lat, S1Angle lng)
      : _latRadians = lat.radians,
        _lngRadians = lng.radians;

  /// Returns the latitude of the given point as an S1Angle.
  static S1Angle latitude(S2Point p) {
    return S1Angle.radians(
      math.atan2(p.z + 0.0, math.sqrt(p.x * p.x + p.y * p.y)),
    );
  }

  /// Returns the longitude of the given point as an S1Angle.
  static S1Angle longitude(S2Point p) {
    return S1Angle.radians(math.atan2(p.y + 0.0, p.x + 0.0));
  }

  /// Returns the latitude of this point as a new S1Angle.
  S1Angle get lat => S1Angle.radians(_latRadians);

  /// Returns the latitude of this point as radians.
  double get latRadians => _latRadians;

  /// Returns the latitude of this point as degrees.
  double get latDegrees => 180.0 / math.pi * _latRadians;

  /// Returns the longitude of this point as a new S1Angle.
  S1Angle get lng => S1Angle.radians(_lngRadians);

  /// Returns the longitude of this point as radians.
  double get lngRadians => _lngRadians;

  /// Returns the longitude of this point as degrees.
  double get lngDegrees => 180.0 / math.pi * _lngRadians;

  /// Return true if this LatLng is normalized.
  bool get isValid => isValidLatLng(_latRadians, _lngRadians);

  /// Return true if the given lat and lng would be a valid LatLng.
  static bool isValidLatLng(double latRadians, double lngRadians) {
    return latRadians.abs() <= S2.piOver2 && lngRadians.abs() <= math.pi;
  }

  /// Returns a new S2LatLng that is normalized.
  S2LatLng get normalized {
    return S2LatLng.fromRadians(
      math.max(-S2.piOver2, math.min(S2.piOver2, _latRadians)),
      Platform.ieeeRemainder(_lngRadians, 2 * math.pi),
    );
  }

  /// Convert to the equivalent unit-length vector (S2Point).
  S2Point toPoint() {
    assert(_latRadians.isFinite);
    assert(_lngRadians.isFinite);
    final phi = _latRadians;
    final theta = _lngRadians;
    final cosphi = math.cos(phi);
    return S2Point(
      math.cos(theta) * cosphi,
      math.sin(theta) * cosphi,
      math.sin(phi),
    );
  }

  /// Return the distance (measured along the surface of the sphere) to the
  /// given point using the Haversine formula.
  S1Angle getDistance(S2LatLng other) {
    final lat1 = _latRadians;
    final lat2 = other._latRadians;
    final lng1 = _lngRadians;
    final lng2 = other._lngRadians;
    final dlat = math.sin(0.5 * (lat2 - lat1));
    final dlng = math.sin(0.5 * (lng2 - lng1));
    final x = dlat * dlat + dlng * dlng * math.cos(lat1) * math.cos(lat2);
    return S1Angle.radians(2 * math.asin(math.sqrt(math.min(1.0, x))));
  }

  /// Returns the surface distance assuming a constant radius.
  double getDistanceWithRadius(S2LatLng other, double radius) {
    return getDistance(other).radians * radius;
  }

  /// Adds the given point to this point.
  S2LatLng operator +(S2LatLng other) {
    return S2LatLng.fromRadians(
      _latRadians + other._latRadians,
      _lngRadians + other._lngRadians,
    );
  }

  /// Subtracts the given point from this point.
  S2LatLng operator -(S2LatLng other) {
    return S2LatLng.fromRadians(
      _latRadians - other._latRadians,
      _lngRadians - other._lngRadians,
    );
  }

  /// Scales this point by the given scaling factor.
  S2LatLng operator *(double m) {
    return S2LatLng.fromRadians(_latRadians * m, _lngRadians * m);
  }

  /// Adds the given point to this point (method form, Java compatibility).
  S2LatLng add(S2LatLng other) => this + other;

  /// Subtracts the given point from this point (method form, Java compatibility).
  S2LatLng sub(S2LatLng other) => this - other;

  /// Scales this point by the given scaling factor (method form, Java compatibility).
  S2LatLng mul(double m) => this * m;

  @override
  bool operator ==(Object other) {
    if (other is S2LatLng) {
      return _latRadians == other._latRadians && _lngRadians == other._lngRadians;
    }
    return false;
  }

  @override
  int get hashCode {
    int value = 17;
    value = 37 * value + _latRadians.hashCode;
    value = 37 * value + _lngRadians.hashCode;
    return value;
  }

  /// Returns true if both the latitude and longitude of the given point are
  /// within [maxError] radians of this point.
  bool approxEquals(S2LatLng other, [double maxError = 1e-9]) {
    return (_latRadians - other._latRadians).abs() < maxError &&
        (_lngRadians - other._lngRadians).abs() < maxError;
  }

  @override
  String toString() => '($_latRadians, $_lngRadians)';

  /// Returns a String with the lat and lng in degrees.
  String toStringDegrees() => '($latDegrees, $lngDegrees)';
}

