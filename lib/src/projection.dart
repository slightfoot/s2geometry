// Copyright 2022 Google Inc.
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
import 'r2_vector.dart';
import 's2_latlng.dart';
import 's2_point.dart';

/// For the purposes of the S2 library, a projection is a function that maps 
/// between S2Points and R2Points. It can also define the coordinate wrapping 
/// behavior along each axis.
abstract class Projection {
  /// Converts a point on the sphere to a projected 2D point.
  R2Vector project(S2Point p) => fromLatLng(S2LatLng.fromPoint(p));

  /// Converts a projected 2D point to a point on the sphere.
  ///
  /// If wrapping is defined for a given axis (see below), then this method 
  /// should accept any real number for the corresponding coordinate.
  S2Point unproject(R2Vector p) => toLatLng(p).toPoint();

  /// Convenience function equivalent to Project(ll.ToPoint()), but the 
  /// implementation may be more efficient.
  R2Vector fromLatLng(S2LatLng ll);

  /// Convenience function equivalent to S2LatLng(Unproject(p)), but the 
  /// implementation may be more efficient.
  S2LatLng toLatLng(R2Vector p);

  /// Returns the point obtained by interpolating the given fraction of the 
  /// distance along the line from A to B. Almost all projections should use 
  /// the default implementation of this method, which simply interpolates 
  /// linearly in R2 space. Fractions less than 0 or greater than 1 result in
  /// extrapolation instead.
  static R2Vector interpolate(double f, R2Vector a, R2Vector b) {
    return a.mul(1 - f).add(b.mul(f));
  }

  /// Defines the coordinate wrapping distance along each axis. If this value 
  /// is non-zero for a given axis, the coordinates are assumed to "wrap" with 
  /// the given period.
  R2Vector get wrapDistance;

  /// Helper function that wraps the coordinates of B if necessary in order to 
  /// obtain the shortest edge AB.
  R2Vector wrapDestination(R2Vector a, R2Vector b) {
    final wrap = wrapDistance;
    double x = b.x;
    double y = b.y;
    if (wrap.x > 0 && (x - a.x).abs() > 0.5 * wrap.x) {
      x -= ((x - a.x) / wrap.x).round() * wrap.x;
    }
    if (wrap.y > 0 && (y - a.y).abs() > 0.5 * wrap.y) {
      y -= ((y - a.y) / wrap.y).round() * wrap.y;
    }
    return R2Vector(x, y);
  }
}

/// MercatorProjection defines the spherical Mercator projection. Google Maps 
/// uses this projection together with WGS84 coordinates, in which case it is 
/// known as the "Web Mercator" projection.
class MercatorProjection extends Projection {
  final double _xWrap;
  final double _toRadians;
  final double _fromRadians;

  /// Default constructor with the projected 'x' coordinate in [-pi, pi].
  MercatorProjection.inRadians() : this(math.pi);

  /// Constructs a Mercator projection where "x" corresponds to longitude in 
  /// the range [-maxX, maxX] and "y" corresponds to latitude.
  MercatorProjection(double maxX)
      : _xWrap = 2 * maxX,
        _toRadians = math.pi / maxX,
        _fromRadians = maxX / math.pi;

  @override
  R2Vector fromLatLng(S2LatLng ll) {
    final sinPhi = math.sin(ll.latRadians);
    final y = 0.5 * math.log((1 + sinPhi) / (1 - sinPhi));
    return R2Vector(_fromRadians * ll.lngRadians, _fromRadians * y);
  }

  @override
  S2LatLng toLatLng(R2Vector p) {
    final x = _toRadians * Platform.ieeeRemainder(p.x, _xWrap);
    final k = math.exp(2 * _toRadians * p.y);
    final y = k.isInfinite ? math.pi / 2 : math.asin((k - 1) / (k + 1));
    return S2LatLng.fromRadians(y, x);
  }

  @override
  R2Vector get wrapDistance => R2Vector(_xWrap, 0);
}

/// PlateCarreeProjection defines the "plate carree" (square plate) projection,
/// which converts points on the sphere to (longitude, latitude) pairs.
class PlateCarreeProjection extends Projection {
  final double _xWrap;
  final double _toRadians;
  final double _fromRadians;

  /// Constructor which by default sets the scale to PI.
  PlateCarreeProjection.inRadians() : this(math.pi);

  /// Constructs the plate carree projection where the x coordinates (longitude) 
  /// span [-scale, scale] and the y coordinates (latitude) span [-scale/2, scale/2].
  PlateCarreeProjection(double scale)
      : _xWrap = 2 * scale,
        _toRadians = math.pi / scale,
        _fromRadians = scale / math.pi;

  @override
  R2Vector fromLatLng(S2LatLng ll) {
    return R2Vector(_fromRadians * ll.lngRadians, _fromRadians * ll.latRadians);
  }

  @override
  S2LatLng toLatLng(R2Vector p) {
    return S2LatLng.fromRadians(
      _toRadians * p.y,
      _toRadians * Platform.ieeeRemainder(p.x, _xWrap),
    );
  }

  @override
  R2Vector get wrapDistance => R2Vector(_xWrap, 0);
}

