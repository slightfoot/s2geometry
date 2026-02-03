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

import 's2_cap.dart';
import 's2_cell.dart';
import 's2_cell_id.dart';
import 's2_latlng_rect.dart';
import 's2_point.dart';

/// An S2Region represents a two-dimensional region over the unit sphere.
/// It is an abstract interface with various concrete subtypes.
///
/// The main purpose of this interface is to allow complex regions to be
/// approximated as simpler regions. So rather than having a wide variety
/// of virtual methods that are implemented by all subtypes, the interface
/// is restricted to methods that are useful for computing approximations.
abstract class S2Region {
  /// Returns a bounding spherical cap.
  S2Cap get capBound;

  /// Returns a bounding latitude-longitude rectangle.
  S2LatLngRect get rectBound;

  /// Adds a small collection of cells to [results] whose union covers this
  /// region. The cells are not sorted, may have redundancies (such as cells
  /// that contain other cells), and may cover much more area than necessary.
  ///
  /// This method is not intended for direct use by client code. Clients
  /// should typically use S2RegionCoverer.getCovering, which has options to
  /// control the size and accuracy of the covering.
  ///
  /// The default implementation uses capBound's getCellUnionBound.
  void getCellUnionBound(List<S2CellId> results) {
    capBound.getCellUnionBound(results);
  }

  /// If this method returns true, the region completely contains the given
  /// cell. Otherwise, either the region does not contain the cell or the
  /// containment relationship could not be determined.
  bool containsCell(S2Cell cell);

  /// Returns true if and only if the given point is contained by the region.
  /// [p] is generally required to be unit length, although some subtypes
  /// may relax this restriction.
  bool containsPoint(S2Point p);

  /// If this method returns false, the region does not intersect the given
  /// cell. Otherwise, either the region intersects the cell, or the
  /// intersection relationship could not be determined.
  bool mayIntersect(S2Cell cell);
}

