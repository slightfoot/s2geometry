// Copyright 2014 Google Inc.
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

import 'package:collection/collection.dart';

import 's2_cap.dart';
import 's2_cell.dart';
import 's2_cell_id.dart';
import 's2_latlng_rect.dart';
import 's2_point.dart';
import 's2_region.dart';

/// An S2RegionIntersection represents an intersection of overlapping regions.
/// It is convenient for computing a covering of the intersection of a set of
/// regions. The regions are assumed to be immutable.
///
/// Note: An intersection of no regions covers the entire sphere.
class S2RegionIntersection implements S2Region {
  final List<S2Region> _regions;
  S2LatLngRect? _cachedRectBound;

  /// Creates an intersection from a copy of [regions].
  S2RegionIntersection(Iterable<S2Region> regions) : _regions = List.from(regions);

  /// Returns true if all the regions fully contain the cell.
  @override
  bool containsCell(S2Cell cell) {
    for (final region in _regions) {
      if (!region.containsCell(cell)) {
        return false;
      }
    }
    return true;
  }

  /// Returns true if all the regions fully contain the point.
  @override
  bool containsPoint(S2Point point) {
    for (final region in _regions) {
      if (!region.containsPoint(point)) {
        return false;
      }
    }
    return true;
  }

  @override
  S2Cap get capBound {
    // This could be optimized to return a tighter bound, but doesn't seem 
    // worth it unless profiling shows otherwise.
    return rectBound.capBound;
  }

  @override
  S2LatLngRect get rectBound {
    if (_cachedRectBound != null) {
      return _cachedRectBound!;
    }

    _cachedRectBound = S2LatLngRect.full();
    for (final region in _regions) {
      _cachedRectBound = _cachedRectBound!.intersection(region.rectBound);
    }
    return _cachedRectBound!;
  }

  /// Returns true if the cell may intersect all regions in this collection.
  @override
  bool mayIntersect(S2Cell cell) {
    for (final region in _regions) {
      if (!region.mayIntersect(cell)) {
        return false;
      }
    }
    return true;
  }

  @override
  void getCellUnionBound(List<S2CellId> results) {
    capBound.getCellUnionBound(results);
  }

  /// Returns true if this S2RegionIntersection is equal to another 
  /// S2RegionIntersection, where each region must be equal and in the same order.
  /// This method is intended only for testing purposes.
  /// NOTE: This should be rewritten to disregard order if such functionality 
  /// is ever required.
  @override
  bool operator ==(Object other) {
    if (other is! S2RegionIntersection) return false;
    return const ListEquality().equals(_regions, other._regions);
  }

  @override
  int get hashCode => const ListEquality().hash(_regions);
}

