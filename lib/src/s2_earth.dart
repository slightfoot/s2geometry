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

import 'dart:math' as math;

import 's1_angle.dart';
import 's1_chord_angle.dart';
import 's2_latlng.dart';
import 's2_point.dart';

/// The Earth modeled as a sphere.
///
/// Provides many convenience functions so that it doesn't take 2 lines of code
/// just to do a single conversion. Note that the conversions between angles
/// and distances on the Earth's surface provided here rely on modeling Earth
/// as a sphere; otherwise a given angle would correspond to a range of
/// distances depending on where the corresponding line segment was located.
///
/// More sophisticated Earth models (such as WGS84) should be used if required
/// for accuracy or interoperability.
class S2Earth {
  S2Earth._();

  /// Returns the Earth's mean radius in meters.
  ///
  /// The Earth's mean radius is the radius of the equivalent sphere with the
  /// same surface area. According to NASA, this value is 6371.01 +/- 0.02 km.
  /// The equatorial radius is 6378.136 km, and the polar radius is 6356.752 km.
  /// They differ by one part in 298.257.
  static double get radiusMeters => 6371010.0;

  /// Returns the Earth's mean radius in kilometers.
  static double get radiusKm => 0.001 * radiusMeters;

  /// Returns the altitude of the lowest known point on Earth (-10898 meters).
  static double get lowestAltitudeMeters => -10898;

  /// Returns the altitude of the highest known point on Earth (8846 meters).
  static double get highestAltitudeMeters => 8846;

  /// Converts the given distance in meters to an S1Angle.
  static S1Angle metersToAngle(double distanceMeters) {
    return S1Angle.radians(metersToRadians(distanceMeters));
  }

  /// Converts the given distance in meters to an S1ChordAngle.
  static S1ChordAngle metersToChordAngle(double distanceMeters) {
    return S1ChordAngle.fromRadians(metersToRadians(distanceMeters));
  }

  /// Converts the given S1Angle to meters.
  static double toMetersFromAngle(S1Angle angle) {
    return angle.radians * radiusMeters;
  }

  /// Converts the given S1ChordAngle to meters.
  static double toMetersFromChordAngle(S1ChordAngle chordAngle) {
    return chordAngle.radians * radiusMeters;
  }

  /// Converts the given S1Angle to kilometers.
  static double toKm(S1Angle angle) {
    return angle.radians * radiusKm;
  }

  /// Converts the given kilometers to radians.
  static double kmToRadians(double km) => km / radiusKm;

  /// Converts the given radians to kilometers.
  static double radiansToKm(double radians) => radians * radiusKm;

  /// Converts the given meters to radians.
  static double metersToRadians(double meters) => meters / radiusMeters;

  /// Converts the given radians to meters.
  static double radiansToMeters(double radians) => radians * radiusMeters;

  /// Converts the given square kilometers to steradians.
  static double squareKmToSteradians(double km2) => km2 / (radiusKm * radiusKm);

  /// Converts the given square meters to steradians.
  static double squareMetersToSteradians(double m2) =>
      m2 / (radiusMeters * radiusMeters);

  /// Converts the given steradians to square kilometers.
  static double steradiansToSquareKm(double steradians) =>
      steradians * radiusKm * radiusKm;

  /// Converts the given steradians to square meters.
  static double steradiansToSquareMeters(double steradians) =>
      steradians * radiusMeters * radiusMeters;

  /// Returns the distance between two S2Points on the globe in kilometers.
  static double getDistanceKmPoints(S2Point a, S2Point b) {
    return radiansToKm(a.angle(b));
  }

  /// Returns the distance between two S2LatLngs on the globe in kilometers.
  static double getDistanceKmLatLng(S2LatLng a, S2LatLng b) {
    return toKm(a.getDistance(b));
  }

  /// Returns the distance between two S2Points on the globe in meters.
  static double getDistanceMetersPoints(S2Point a, S2Point b) {
    return radiansToMeters(a.angle(b));
  }

  /// Returns the distance between two S2LatLngs on the globe in meters.
  static double getDistanceMetersLatLng(S2LatLng a, S2LatLng b) {
    return toMetersFromAngle(a.getDistance(b));
  }

  /// Returns the Haversine of the angle.
  ///
  /// The versine is 1-cos(theta) and the haversine is "half" of the versine
  /// or (1-cos(theta))/2. Haversine(x) has very good numerical stability
  /// around zero.
  static double haversine(double angle) {
    final halfSin = math.sin(angle / 2);
    return halfSin * halfSin;
  }

  /// Calculates the bearing angle between two S2LatLngs.
  ///
  /// Returns the bearing at the location of the first point, oriented
  /// clockwise from north, in the range -pi to pi.
  static S1Angle getInitialBearing(S2LatLng a, S2LatLng b) {
    final lat1 = a.latRadians;
    final cosLat2 = math.cos(b.latRadians);
    final latDiff = b.latRadians - a.latRadians;
    final lngDiff = b.lngRadians - a.lngRadians;

    final x = math.sin(latDiff) +
        math.sin(lat1) * cosLat2 * 2 * haversine(lngDiff);
    final y = math.sin(lngDiff) * cosLat2;
    return S1Angle.radians(math.atan2(y, x));
  }
}

