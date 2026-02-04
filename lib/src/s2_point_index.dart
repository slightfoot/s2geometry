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

import 'dart:collection';

import 's2_cell_id.dart';
import 's2_point.dart';

/// S2PointIndex maintains an index of points. Each point has some associated
/// client-supplied data, such as an index or object the point was taken from,
/// useful to map query results back to another data structure.
///
/// The class supports adding or removing points dynamically, and provides a
/// seekable iterator interface for navigating the index.
class S2PointIndex<D> {
  final SplayTreeSet<PointIndexEntry<D>> _entries;

  /// Creates a new S2PointIndex.
  S2PointIndex() : _entries = SplayTreeSet<PointIndexEntry<D>>(
    PointIndexEntry.order<D>(),
  );

  /// Creates a new S2PointIndex for a Data type D that is Comparable.
  static S2PointIndex<D> forComparableData<D extends Comparable<dynamic>>() {
    return S2PointIndex<D>._withComparator(PointIndexEntry.stableOrder<D>());
  }

  S2PointIndex._withComparator(Comparator<PointIndexEntry<D>> comparator)
      : _entries = SplayTreeSet<PointIndexEntry<D>>(comparator);

  /// Returns the number of points in the index.
  int get numPoints => _entries.length;

  /// Returns true if the index is empty.
  bool get isEmpty => _entries.isEmpty;

  /// Returns a new iterator over the entries of this index.
  PointIndexIterator<D> get iterator => PointIndexIterator<D>._(_entries);

  /// Adds a new point with associated data to the index.
  void add(S2Point point, D? data) {
    addEntry(createEntry(point, data));
  }

  /// Adds a new entry to the index. Invalidates all iterators.
  void addEntry(PointIndexEntry<D> entry) {
    _entries.add(entry);
  }

  /// Removes the given point and data from the index.
  /// Both point and data must match. Returns true if removed.
  bool remove(S2Point point, D? data) {
    return removeEntry(createEntry(point, data));
  }

  /// Removes the given entry from the index. Returns true if removed.
  bool removeEntry(PointIndexEntry<D> entry) {
    return _entries.remove(entry);
  }

  /// Resets the index to its original empty state.
  void reset() {
    _entries.clear();
  }

  /// Creates an index entry from the given point and data value.
  static PointIndexEntry<D> createEntry<D>(S2Point point, D? data) {
    return PointIndexEntry<D>(S2CellId.fromPoint(point), point, data);
  }
}

/// An entry in an S2PointIndex, containing the cell id, point, and data.
class PointIndexEntry<D> implements Comparable<PointIndexEntry<D>> {
  final int _id;
  final S2Point? _point;
  final D? _data;

  PointIndexEntry(S2CellId cellId, S2Point? point, D? data)
      : _id = cellId.id,
        _point = point,
        _data = data;

  /// Returns the cell id as an integer.
  int get id => _id;

  /// Returns the cell id.
  S2CellId get cellId => S2CellId(_id);

  /// Returns the point.
  S2Point? get point => _point;

  /// Returns the data.
  D? get data => _data;

  /// A comparator for Entry<D> when D is Comparable.
  static Comparator<PointIndexEntry<D>> stableOrder<D extends Comparable<dynamic>>() {
    return (a, b) => _compare<D>(a, b, (aData, bData) => aData.compareTo(bData));
  }

  /// A comparator for Entry<D> when D is not Comparable.
  static Comparator<PointIndexEntry<D>> order<D>() {
    return (a, b) => _compare<D>(a, b, (aData, bData) => aData == bData ? 0 : -1);
  }

  static int _compare<D>(
      PointIndexEntry<D> a, PointIndexEntry<D> b, int Function(D, D) dataCompare) {
    if (identical(a, b)) return 0;

    int cmp = S2CellId.unsignedLessThan(a._id, b._id)
        ? -1
        : (S2CellId.unsignedLessThan(b._id, a._id) ? 1 : 0);
    if (cmp != 0) return cmp;

    if (a._point == null && b._point == null) {
      cmp = 0;
    } else if (a._point == null) {
      return -1;
    } else if (b._point == null) {
      return 1;
    } else {
      cmp = a._point!.compareTo(b._point!);
    }
    if (cmp != 0) return cmp;

    if (a._data == null && b._data == null) {
      return 0;
    } else if (a._data == null) {
      return -1;
    } else if (b._data == null) {
      return 1;
    }
    return dataCompare(a._data as D, b._data as D);
  }

  @override
  int compareTo(PointIndexEntry<D> other) {
    return S2CellId.unsignedLessThan(_id, other._id)
        ? -1
        : (S2CellId.unsignedLessThan(other._id, _id) ? 1 : 0);
  }

  @override
  bool operator ==(Object other) {
    if (other is PointIndexEntry<D>) {
      return (_point == null && other._point == null ||
              _point != null && other._point != null && _point == other._point) &&
          _data == other._data;
    }
    return false;
  }

  @override
  int get hashCode {
    return _point.hashCode * 31 + (_data == null ? 0 : _data.hashCode);
  }

  @override
  String toString() {
    return '${_point?.toDegreesString() ?? 'null'} : $_data';
  }
}

/// A seekable iterator over the entries of an S2PointIndex.
class PointIndexIterator<D> {
  final List<PointIndexEntry<D>> _entries;
  int _position = 0;

  PointIndexIterator._(SplayTreeSet<PointIndexEntry<D>> entries)
      : _entries = entries.toList();

  /// Returns true if the iterator is at the beginning.
  bool get atBegin => _position == 0;

  /// Returns true if the iterator is past the end.
  bool get done => _position >= _entries.length;

  /// Returns the current entry, or null if done.
  PointIndexEntry<D>? get entry => done ? null : _entries[_position];

  /// Returns the cell id of the current entry.
  int get id => done ? 0 : _entries[_position].id;

  /// Returns the cell id of the current entry as S2CellId.
  S2CellId get cellId => S2CellId(id);

  /// Moves to the next entry. Returns true if successful.
  bool next() {
    if (_position < _entries.length) {
      _position++;
    }
    return !done;
  }

  /// Moves to the previous entry. Returns true if successful.
  bool prev() {
    if (_position > 0) {
      _position--;
      return true;
    }
    return false;
  }

  /// Restarts the iterator to the beginning.
  void restart() {
    _position = 0;
  }

  /// Moves the iterator past the end.
  void finish() {
    _position = _entries.length;
  }

  /// Seeks to the first entry with id >= target.
  void seek(S2CellId target) {
    _position = _lowerBound(target.id);
  }

  /// Seeks forward to the first entry with id >= target.
  /// Does not move backward.
  void seekForward(S2CellId target) {
    final pos = _lowerBound(target.id);
    if (pos > _position) {
      _position = pos;
    }
  }

  int _lowerBound(int targetId) {
    int low = 0;
    int high = _entries.length;
    while (low < high) {
      final mid = (low + high) ~/ 2;
      if (S2CellId.unsignedLessThan(_entries[mid].id, targetId)) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return low;
  }

  /// Returns a copy of this iterator.
  PointIndexIterator<D> copy() {
    final result = PointIndexIterator<D>._entries(_entries);
    result._position = _position;
    return result;
  }

  PointIndexIterator._entries(this._entries);
}
