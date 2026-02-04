// Copyright 2024 Google Inc. All Rights Reserved.
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
import 'dart:typed_data';

import 'pullable.dart';
import 's2_point.dart';

/// MutableS2Point is an interface to an XYZ coordinate.
abstract class MutableS2Point implements Comparable<MutableS2Point> {
  /// Returns the x coordinate of this point.
  double getX();

  /// Returns the y coordinate of this point.
  double getY();

  /// Returns the z coordinate of this point.
  double getZ();

  /// Sets the coordinates of this point to equal the given S2Point.
  void setFromPoint(S2Point other);

  /// Sets the coordinates of this point to the given X, Y, and Z values.
  void set(double x, double y, double z);

  /// Returns true if this MutableS2Point is currently equal to the given S2Point.
  bool isEqualTo(S2Point other) {
    return getX() == other.getX() && getY() == other.getY() && getZ() == other.getZ();
  }

  /// Returns true if this MutableS2Point is currently equal to the given MutableS2Point.
  bool isEqualToMutable(MutableS2Point other) {
    return getX() == other.getX() && getY() == other.getY() && getZ() == other.getZ();
  }

  @override
  int compareTo(MutableS2Point other) {
    if (getX() < other.getX()) return -1;
    if (other.getX() < getX()) return 1;
    if (getY() < other.getY()) return -1;
    if (other.getY() < getY()) return 1;
    if (getZ() < other.getZ()) return -1;
    if (other.getZ() < getZ()) return 1;
    return 0;
  }
}

/// A trivial implementation of MutableS2Point.
class MutableS2PointImpl extends MutableS2Point {
  double _x = 0;
  double _y = 0;
  double _z = 0;

  @override
  void set(double x, double y, double z) {
    _x = x;
    _y = y;
    _z = z;
  }

  @override
  void setFromPoint(S2Point other) {
    _x = other.getX();
    _y = other.getY();
    _z = other.getZ();
  }

  @override
  double getZ() => _z;

  @override
  double getY() => _y;

  @override
  double getX() => _x;

  @override
  String toString() => '($_x, $_y, $_z)';
}

/// A visitor of points as X,Y,Z values.
typedef PointVisitor = bool Function(double x, double y, double z);

/// A visitor of indexed points, as an index and X,Y,Z values.
typedef PointOffsetVisitor = bool Function(int index, double x, double y, double z);

/// MutableS2PointList is a list of MutableS2Points, stored as a single array of doubles.
class MutableS2PointList extends PullList<MutableS2Point> {
  /// The default initial capacity, as the number of points.
  static const int defaultCapacity = 16;

  /// Java compatibility constant.
  static const int DEFAULT_CAPACITY = defaultCapacity;

  /// The points, stored as consecutive X,Y,Z triples.
  Float64List _coordinates;

  /// The current number of points stored in the list.
  int _size;

  /// The current capacity of the list.
  int _capacity;

  /// Creates a new, empty MutableS2PointList with a default initial capacity.
  MutableS2PointList()
      : _coordinates = Float64List(defaultCapacity * 3),
        _size = 0,
        _capacity = defaultCapacity;

  /// Constructs a new MutableS2PointList with a given initial size and capacity.
  MutableS2PointList.withSize(int size)
      : _coordinates = Float64List(size * 3),
        _size = size,
        _capacity = size;

  /// Copy constructor.
  MutableS2PointList.from(MutableS2PointList other)
      : _coordinates = Float64List.fromList(
            other._coordinates.sublist(0, other._size * 3)),
        _size = other._size,
        _capacity = other._size;

  /// Creates a new, empty MutableS2PointList with a given capacity.
  static MutableS2PointList ofCapacity(int capacity) {
    final list = MutableS2PointList();
    list.ensureCapacity(capacity);
    return list;
  }

  /// Creates a new MutableS2PointList of capacity and size both equal to 2.
  static MutableS2PointList pair() => MutableS2PointList.withSize(2);

  @override
  bool ensureCapacity(int requiredCapacity) {
    if (requiredCapacity <= _capacity) {
      return false;
    }
    int newCapacity = _highestOneBit(requiredCapacity);
    newCapacity = (newCapacity == requiredCapacity) ? newCapacity : newCapacity << 1;
    final newCoords = Float64List(newCapacity * 3);
    newCoords.setRange(0, _coordinates.length, _coordinates);
    _coordinates = newCoords;
    _capacity = newCapacity;
    return true;
  }

  static int _highestOneBit(int value) {
    if (value <= 0) return 0;
    int result = 1;
    while (result <= value ~/ 2) {
      result <<= 1;
    }
    return result;
  }

  @override
  void enlarge(int newSize) {
    ensureCapacity(newSize);
    if (newSize > _size) {
      _size = newSize;
    }
  }

  @override
  void truncate(int newSize) {
    if (newSize < _size) {
      _size = newSize;
    }
  }

  @override
  int get size => _size;

  /// Returns the current capacity of the list.
  int get capacity => _capacity;

  @override
  MutableS2Point newElement() => MutableS2PointImpl();

  @override
  void clear() {
    _size = 0;
  }

  /// Sorts this MutableS2PointList using the standard lexicographical ordering.
  void sort() {
    sortWith((a, b) => a.compareTo(b));
  }

  void _rangeCheck(int index) {
    if (index >= _size || index < 0) {
      throw RangeError('index $index out of bounds for size $_size');
    }
  }

  /// Returns a new S2Point with the same coordinates as the MutableS2Point at the given index.
  S2Point getImmutable(int i) {
    _rangeCheck(i);
    return S2Point(_coordinates[i * 3], _coordinates[i * 3 + 1], _coordinates[i * 3 + 2]);
  }

  /// Returns true if the MutableS2Point at the given index equals the given S2Point.
  bool isEqualToAt(int index, S2Point other) {
    _rangeCheck(index);
    final i = index * 3;
    return _coordinates[i + 0] == other.getX() &&
        _coordinates[i + 1] == other.getY() &&
        _coordinates[i + 2] == other.getZ();
  }

  /// Returns true if the MutableS2Point at the given index equals the given MutableS2Point.
  bool isEqualToMutableAt(int index, MutableS2Point other) {
    _rangeCheck(index);
    final i = index * 3;
    return _coordinates[i + 0] == other.getX() &&
        _coordinates[i + 1] == other.getY() &&
        _coordinates[i + 2] == other.getZ();
  }

  /// Returns true if the MutableS2Points at aIndex and bIndex are equal.
  bool isEqualToIndices(int aIndex, int bIndex) {
    final ia = aIndex * 3;
    final ib = bIndex * 3;
    return _coordinates[ia + 0] == _coordinates[ib + 0] &&
        _coordinates[ia + 1] == _coordinates[ib + 1] &&
        _coordinates[ia + 2] == _coordinates[ib + 2];
  }

  @override
  void get(int index, MutableS2Point value) {
    _rangeCheck(index);
    final i = index * 3;
    value.set(_coordinates[i + 0], _coordinates[i + 1], _coordinates[i + 2]);
  }

  /// Returns a view of the MutableS2Point at the given index.
  MutableS2Point getAt(int index) {
    _rangeCheck(index);
    return _MutableS2PointView(this, index * 3);
  }

  @override
  void set(int index, MutableS2Point point) {
    _rangeCheck(index);
    final i = index * 3;
    _coordinates[i + 0] = point.getX();
    _coordinates[i + 1] = point.getY();
    _coordinates[i + 2] = point.getZ();
  }

  /// Sets the coordinates at the given index from an S2Point.
  void setFromS2Point(int index, S2Point point) {
    _rangeCheck(index);
    final i = index * 3;
    _coordinates[i + 0] = point.getX();
    _coordinates[i + 1] = point.getY();
    _coordinates[i + 2] = point.getZ();
  }

  @override
  void copy(int indexA, int indexB) {
    final ia = indexA * 3;
    final ib = indexB * 3;
    _coordinates[ib + 0] = _coordinates[ia + 0];
    _coordinates[ib + 1] = _coordinates[ia + 1];
    _coordinates[ib + 2] = _coordinates[ia + 2];
  }

  @override
  void add(MutableS2Point value) {
    addCoords(value.getX(), value.getY(), value.getZ());
  }

  /// Adds a copy of the given S2Point to the end of the list.
  void addS2Point(S2Point value) {
    addCoords(value.x, value.y, value.z);
  }

  /// Adds a point with the given values to the list.
  void addCoords(double x, double y, double z) {
    ensureCapacity(_size + 1);
    final i = _size * 3;
    _coordinates[i + 0] = x;
    _coordinates[i + 1] = y;
    _coordinates[i + 2] = z;
    _size++;
  }

  /// Provides a List<S2Point> view of this MutableS2PointList.
  List<S2Point> asPointList() => _S2PointListView(this);

  /// Sends each point as X,Y,Z values to the given action.
  bool forEachPoint(PointVisitor action) {
    for (int index = 0; index < _size; index++) {
      final i = index * 3;
      if (!action(_coordinates[i + 0], _coordinates[i + 1], _coordinates[i + 2])) {
        return false;
      }
    }
    return true;
  }

  /// Sends each point as its index and X,Y,Z values to the given action.
  bool forEachIndexedPoint(PointOffsetVisitor action) {
    for (int index = 0; index < _size; index++) {
      final i = index * 3;
      if (!action(index, _coordinates[i + 0], _coordinates[i + 1], _coordinates[i + 2])) {
        return false;
      }
    }
    return true;
  }

  @override
  void swap(int indexA, int indexB) {
    final ia = indexA * 3;
    final ib = indexB * 3;
    final tx = _coordinates[ia + 0];
    final ty = _coordinates[ia + 1];
    final tz = _coordinates[ia + 2];
    _coordinates[ia + 0] = _coordinates[ib + 0];
    _coordinates[ia + 1] = _coordinates[ib + 1];
    _coordinates[ia + 2] = _coordinates[ib + 2];
    _coordinates[ib + 0] = tx;
    _coordinates[ib + 1] = ty;
    _coordinates[ib + 2] = tz;
  }

  /// Compares the points at the given indices.
  int compare(int leftIndex, int rightIndex) {
    final i = leftIndex * 3;
    final j = rightIndex * 3;
    int cmp = _coordinates[i + 0].compareTo(_coordinates[j]);
    if (cmp != 0) return cmp;
    cmp = _coordinates[i + 1].compareTo(_coordinates[j + 1]);
    if (cmp != 0) return cmp;
    return _coordinates[i + 2].compareTo(_coordinates[j + 2]);
  }
}

class _MutableS2PointView extends MutableS2Point {
  final MutableS2PointList _list;
  final int _i;

  _MutableS2PointView(this._list, this._i);

  @override
  double getX() => _list._coordinates[_i];

  @override
  double getY() => _list._coordinates[_i + 1];

  @override
  double getZ() => _list._coordinates[_i + 2];

  @override
  void setFromPoint(S2Point other) {
    _list._coordinates[_i + 0] = other.getX();
    _list._coordinates[_i + 1] = other.getY();
    _list._coordinates[_i + 2] = other.getZ();
  }

  @override
  void set(double x, double y, double z) {
    _list._coordinates[_i + 0] = x;
    _list._coordinates[_i + 1] = y;
    _list._coordinates[_i + 2] = z;
  }

  @override
  String toString() =>
      '(${_list._coordinates[_i + 0]}, ${_list._coordinates[_i + 1]}, ${_list._coordinates[_i + 2]})';
}

class _S2PointListView with ListMixin<S2Point> {
  final MutableS2PointList _list;

  _S2PointListView(this._list);

  @override
  S2Point operator [](int index) => _list.getImmutable(index);

  @override
  void operator []=(int index, S2Point value) {
    _list.setFromS2Point(index, value);
  }

  @override
  int get length => _list.size;

  @override
  set length(int newLength) => _list.resize(newLength);
}

