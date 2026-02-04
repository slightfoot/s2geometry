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

/// An S2RegionUnion represents a union of possibly overlapping regions. It is
/// convenient for computing a covering of a set of regions. The regions are
/// assumed to be immutable.
///
/// However, note that currently, using S2RegionCoverer to compute coverings of
/// S2RegionUnions may produce coverings with considerably less than the
/// requested number of cells in cases of overlapping or tiling regions. This
/// occurs because the current S2RegionUnion.contains implementation for S2Cells
/// only returns true if the cell is fully contained by one of the regions. So,
/// cells along internal boundaries in the region union will be subdivided by
/// the coverer even though this is unnecessary, using up the maxSize cell
/// budget. Then, when the coverer normalizes the covering, groups of 4 sibling
/// cells along these internal borders will be replaced by parents, resulting in
/// coverings that may have significantly fewer than maxSize cells, and so are
/// less accurate. This is not a concern for unions of disjoint regions.
class S2RegionUnion implements S2Region {
  final List<S2Region> _regions;
  S2Cap? _cachedCapBound;
  S2LatLngRect? _cachedRectBound;

  /// Creates a region that intersects or contains cells if any of the given
  /// regions does. Makes a copy of 'regions'.
  S2RegionUnion(Iterable<S2Region> regions) : _regions = List.from(regions);

  /// Only returns true if one of the regions in the union fully contains the cell.
  @override
  bool containsCell(S2Cell cell) {
    for (final region in _regions) {
      if (region.containsCell(cell)) {
        return true;
      }
    }
    return false;
  }

  /// Only returns true if one of the regions contains the point.
  @override
  bool containsPoint(S2Point point) {
    for (final region in _regions) {
      if (region.containsPoint(point)) {
        return true;
      }
    }
    return false;
  }

  @override
  S2Cap get capBound {
    if (_cachedCapBound != null) {
      return _cachedCapBound!;
    }

    _cachedCapBound = S2Cap.empty();
    for (final region in _regions) {
      _cachedCapBound = _cachedCapBound!.addCap(region.capBound);
    }
    return _cachedCapBound!;
  }

  @override
  S2LatLngRect get rectBound {
    if (_cachedRectBound != null) {
      return _cachedRectBound!;
    }

    _cachedRectBound = S2LatLngRect.empty();
    for (final region in _regions) {
      _cachedRectBound = _cachedRectBound!.union(region.rectBound);
    }
    return _cachedRectBound!;
  }

  /// Returns true if the cell may intersect any region in this collection.
  @override
  bool mayIntersect(S2Cell cell) {
    for (final region in _regions) {
      if (region.mayIntersect(cell)) {
        return true;
      }
    }
    return false;
  }

  @override
  void getCellUnionBound(List<S2CellId> results) {
    capBound.getCellUnionBound(results);
  }

  /// Returns true if this S2RegionUnion is equal to another S2RegionUnion,
  /// where each region must be equal and in the same order.
  @override
  bool operator ==(Object other) {
    if (other is! S2RegionUnion) return false;
    return const ListEquality().equals(_regions, other._regions);
  }

  @override
  int get hashCode => const ListEquality().hash(_regions);
}

