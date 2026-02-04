// Copyright 2015 Google Inc. All Rights Reserved.
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

import 's2_cell_id.dart';
import 's2_point.dart';

/// The relationship between a target cell and the cells in an index.
enum CellRelation {
  /// Target is contained by an index cell.
  indexed,
  /// Target is subdivided into one or more index cells.
  subdivided,
  /// Target does not intersect any index cells.
  disjoint,
}

/// An interface to provide the cell ID for an element in a sorted list.
abstract class S2IteratorEntry {
  /// Returns the cell ID of this cell as a primitive.
  int get id;
}

/// A random access iterator that provides low-level access to entries sorted
/// by cell ID. The behavior of this iterator is more like a database cursor,
/// where accessing properties at the current position does not alter the
/// position of the cursor.
abstract class S2Iterator<T extends S2IteratorEntry> {
  /// Returns a copy of this iterator, positioned as this iterator is.
  S2Iterator<T> copy();

  /// Positions the iterator so that [atBegin] is true.
  void restart();

  /// Returns the comparison from the current iterator cell to the given cell ID.
  int compareTo(S2CellId target) {
    return cellId.compareTo(target);
  }

  /// Returns the cell id for the current cell.
  S2CellId get cellId => S2CellId(entry.id);

  /// Returns the current entry.
  T get entry;

  /// Returns the center of the cell (used as a reference point for shape interiors.)
  S2Point get center => cellId.toPoint();

  /// If [pos] is equal to the number of cells in the index, does not move the
  /// iterator, and returns false. Otherwise, advances the iterator to the next
  /// cell in the index and returns true.
  bool next();

  /// If [pos] is equal to 0, does not move the iterator and returns false.
  /// Otherwise, positions the iterator at the previous cell in the index and
  /// returns true.
  bool prev();

  /// Returns true if the iterator is positioned past the last index cell.
  bool get done;

  /// Returns true if the iterator is positioned at the first index cell.
  bool get atBegin;

  /// Positions the iterator at the first cell with [cellId] >= [target], or at
  /// the end of the index if no such cell exists.
  void seek(S2CellId target);

  /// Advances the iterator to the next cell with [cellId] >= [target]. If the
  /// iterator is [done] or already satisfies [cellId] >= [target], there is no effect.
  void seekForward(S2CellId target) {
    if (!done && compareTo(target) < 0) {
      seek(target);
    }
  }

  /// Positions the iterator so that [done] is true.
  void finish();

  /// Positions the iterator at the index cell containing [targetPoint] and
  /// returns true, or if no such cell exists in the index, the iterator is
  /// positioned arbitrarily and this method returns false.
  ///
  /// The resulting index position is guaranteed to contain all edges that might
  /// intersect the line segment between [targetPoint] and [center].
  bool locatePoint(S2Point targetPoint) {
    // Let I be the first cell not less than T, where T is the leaf cell
    // containing "targetPoint". Then if T is contained by an index cell, then
    // the containing cell is either I or I'. We test for containment by
    // comparing the ranges of leaf cells spanned by T, I, and I'.
    final target = S2CellId.fromPoint(targetPoint);
    seek(target);
    if (!done && cellId.rangeMin.lessOrEquals(target)) {
      return true;
    }
    if (!atBegin) {
      prev();
      if (cellId.rangeMax.greaterOrEquals(target)) {
        return true;
      }
    }
    return false;
  }

  /// Positions the iterator at the index cell containing the given cell, if
  /// possible, and returns the [CellRelation] that describes the relationship
  /// between the index and the given target cell.
  CellRelation locateCellId(S2CellId target) {
    // Let T be the target, let I be the first cell not less than T.rangeMin(),
    // and let I' be the predecessor of I. If T contains any index cells, then
    // T contains I. Similarly, if T is contained by an index cell, then the
    // containing cell is either I or I'. We test for containment by comparing
    // the ranges of leaf cells spanned by T, I, and I'.
    seek(target.rangeMin);
    if (!done) {
      if (cellId.greaterOrEquals(target) && cellId.rangeMin.lessOrEquals(target)) {
        return CellRelation.indexed;
      }
      if (cellId.lessOrEquals(target.rangeMax)) {
        return CellRelation.subdivided;
      }
    }
    if (!atBegin) {
      prev();
      if (cellId.rangeMax.greaterOrEquals(target)) {
        return CellRelation.indexed;
      }
    }
    return CellRelation.disjoint;
  }
}

/// An [S2Iterator] based on a list.
class ListS2Iterator<T extends S2IteratorEntry> extends S2Iterator<T> {
  final List<T> _entries;
  int _pos = 0;

  /// Create a new iterator based on the given list of entries.
  /// Results are undefined if the entries are not in ascending sorted order.
  ListS2Iterator(this._entries);

  /// Private constructor for copying.
  ListS2Iterator._(this._entries, this._pos);

  @override
  S2Iterator<T> copy() {
    return ListS2Iterator._(_entries, _pos);
  }

  @override
  void restart() {
    _pos = 0;
  }

  @override
  T get entry {
    assert(!done);
    return _entries[_pos];
  }

  @override
  bool next() {
    if (_pos < _entries.length) {
      _pos++;
      return true;
    }
    return false;
  }

  @override
  bool prev() {
    if (_pos > 0) {
      _pos--;
      return true;
    }
    return false;
  }

  @override
  bool get done => _pos == _entries.length;

  @override
  bool get atBegin => _pos == 0;

  @override
  void seek(S2CellId target) {
    _seekFrom(0, target);
  }

  @override
  void seekForward(S2CellId target) {
    _seekFrom(_pos, target);
  }

  void _seekFrom(int start, S2CellId target) {
    int end = _entries.length - 1;
    while (start <= end) {
      _pos = (start + end) ~/ 2;
      final result = cellId.compareTo(target);
      if (result > 0) {
        end = _pos - 1;
      } else if (result < 0) {
        start = _pos + 1;
      } else if (start != _pos) {
        end = _pos;
      } else {
        return;
      }
    }
    _pos = start;
  }

  @override
  void finish() {
    _pos = _entries.length;
  }
}

