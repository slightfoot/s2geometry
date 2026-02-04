// Copyright 2011 Google Inc.
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

import 's2_point.dart';

/// The area of an interior, i.e. the region on the left side of an odd number
/// of loops and optionally a centroid. The area is measured in steradians, and
/// is between 0 and 4*Pi. If it has a centroid, it is the true centroid of the
/// interior multiplied by the area of the shape. Note that the centroid may
/// not be contained by the shape.
class S2AreaCentroid {
  final double _area;
  final S2Point? _centroid;

  /// Constructs a new S2AreaCentroid with an area and optional centroid.
  S2AreaCentroid(this._area, [this._centroid]);

  /// Returns the area of a shape interior in steradians, i.e. the region on
  /// the left side of an odd number of loops. The return value is between 0
  /// and 4*Pi.
  double get area => _area;

  /// Returns the true centroid of a shape, scaled by the area of the shape.
  /// Note that this not a unit-length vector. The centroid might not be
  /// contained by the shape.
  S2Point? get centroid => _centroid;

  @override
  bool operator ==(Object other) {
    if (other is S2AreaCentroid) {
      if (_area != other._area) return false;
      if (_centroid == null && other._centroid == null) return true;
      if (_centroid == null || other._centroid == null) return false;
      return _centroid == other._centroid;
    }
    return false;
  }

  @override
  int get hashCode => Object.hash(_area, _centroid);
}

