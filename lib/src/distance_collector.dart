// Copyright 2021 Google Inc.
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

import 's1_distance.dart';
import 's2_cell.dart';
import 's2_point.dart';

/// DistanceCollector is an interface for working with abstract distances, 
/// tracking the current "best" distance seen over a sequence of update calls. 
/// This can be better than simply computing the distance and retaining the 
/// best, because the current best can often be used to determine that the 
/// new distance cannot be better more cheaply than actually determining the 
/// precise distance.
///
/// The meaning of "best" distance is left up to the implementation. The 
/// provided update methods support finding a best distance between S2 points, 
/// edges, and cells. Current implementations support finding minimum and 
/// maximum distances.
abstract class DistanceCollector<T extends S1Distance<T>> implements Comparable<DistanceCollector<T>> {
  /// Returns the current best distance. If distance() is called on a 
  /// DistanceCollector for which update() and set() have not been called 
  /// since the collector was constructed or reset, the distance will be an 
  /// invalid value, worse than any valid distance.
  T get distance;

  /// Resets this collector to the default, worst value.
  void reset();

  /// Sets this collector to the given distance value.
  void set(T value);

  /// This default implementation of Comparable relies on S1Distance being 
  /// comparable.
  @override
  int compareTo(DistanceCollector<T> other) {
    return distance.compareTo(other.distance);
  }

  /// Update this collector to the better of the current distance and the 
  /// given 'other' distance. Returns true if this distance was updated, 
  /// false otherwise.
  bool update(T other);

  /// Update this collector to the better of the current distance, and the 
  /// distance between the two given points. Returns true if this distance 
  /// was updated, false otherwise.
  bool updatePointToPoint(S2Point p1, S2Point p2);

  /// Update this collector to the better of the current distance, and the 
  /// distance between the given point and edge. Returns true if this 
  /// distance was updated, false otherwise.
  bool updatePointToEdge(S2Point p, S2Point v0, S2Point v1);

  /// Update this collector to the better of the current distance, and the 
  /// distance between the two given edges. Returns true if this distance 
  /// was updated, false otherwise.
  bool updateEdgeToEdge(S2Point v0, S2Point v1, S2Point w0, S2Point w1);

  /// Update this collector to the better of the current distance, and the 
  /// distance between the given point and cell. Returns true if this 
  /// distance was updated, false otherwise.
  bool updatePointToCell(S2Point p, S2Cell c);

  /// Update this collector to the better of the current distance, and the 
  /// distance between the given edge and cell. Returns true if this 
  /// distance was updated, false otherwise.
  bool updateEdgeToCell(S2Point v0, S2Point v1, S2Cell c);

  /// Update this collector to the better of the current distance, and the 
  /// distance between the two given cells. Returns true if this distance 
  /// was updated, false otherwise.
  bool updateCellToCell(S2Cell c1, S2Cell c2);
}

