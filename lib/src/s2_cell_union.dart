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
//
// Dart port of the Google S2 Geometry Library.

import 'dart:math' as math;

import 's1_angle.dart';
import 's1_chord_angle.dart';
import 's2.dart';
import 's2_cap.dart';
import 's2_cell.dart';
import 's2_cell_id.dart';
import 's2_latlng_rect.dart';
import 's2_point.dart';
import 's2_projections.dart';
import 's2_region.dart';

/// An S2CellUnion is a region consisting of cells of various sizes.
///
/// Typically a cell union is used to approximate some other shape. There is a
/// tradeoff between the accuracy of the approximation and how many cells are
/// used. Unlike polygons, cells have a fixed hierarchical structure. This makes
/// them more suitable for optimizations based on preprocessing.
///
/// An S2CellUnion is represented as a list of sorted, non-overlapping S2CellIds.
/// By default the list is also "normalized", meaning that groups of 4 child
/// cells have been replaced by their parent cell whenever possible. S2CellUnions
/// are not required to be normalized, but certain operations will return
/// different results if they are not, e.g. [contains].
class S2CellUnion implements S2Region {
  /// The CellIds that form the Union.
  List<S2CellId> _cellIds = [];

  /// Creates an empty S2CellUnion.
  S2CellUnion();

  /// Creates an S2CellUnion from a list of cell IDs (normalized).
  factory S2CellUnion.fromCellIds(List<S2CellId> cellIds) {
    final union = S2CellUnion();
    union._cellIds = List.from(cellIds);
    union.normalize();
    return union;
  }

  /// Creates an S2CellUnion from raw 64-bit cell IDs (normalized).
  factory S2CellUnion.fromIds(List<int> ids) {
    final union = S2CellUnion();
    union._cellIds = ids.map((id) => S2CellId(id)).toList();
    union.normalize();
    return union;
  }

  /// Creates a copy of another S2CellUnion.
  factory S2CellUnion.copyFrom(S2CellUnion other) {
    final copy = S2CellUnion();
    copy._cellIds = List.from(other._cellIds);
    return copy;
  }

  /// Creates a cell union for the whole sphere.
  factory S2CellUnion.wholeSphere() {
    return S2CellUnion.copyFrom(
      S2CellUnion()..initRawCellIds(List.from(S2CellId.faceCells)),
    );
  }

  /// Creates a cell union from a single cell ID.
  factory S2CellUnion.fromCellId(S2CellId cellId) {
    assert(cellId.isValid);
    final union = S2CellUnion();
    union._cellIds = [cellId];
    return union;
  }

  /// Clears the union contents, leaving it empty.
  void clear() {
    _cellIds.clear();
  }

  /// Populates this cell union with the given S2CellIds, and then normalizes.
  void initFromCellIds(List<S2CellId> cellIds) {
    initRawCellIds(cellIds);
    normalize();
  }

  /// Populates this cell union with the given 64-bit cell ids, and then normalizes.
  void initFromIds(List<int> ids) {
    initRawIds(ids);
    normalize();
  }

  /// Populates this cell union directly (without normalization).
  void initRawCellIds(List<S2CellId> cellIds) {
    _cellIds = cellIds;
  }

  /// Populates this cell union from raw 64-bit IDs (without normalization).
  void initRawIds(List<int> ids) {
    _cellIds = ids.map((id) => S2CellId(id)).toList();
  }

  /// Populates this cell union with a single cell ID.
  void initFromCellId(S2CellId cellId) {
    assert(cellId.isValid);
    _cellIds.clear();
    _cellIds.add(cellId);
  }

  /// Creates a cell union covering the range of leaf cells from [minId] to [maxId] inclusive.
  void initFromMinMax(S2CellId minId, S2CellId maxId) {
    assert(minId.isLeaf);
    assert(maxId.isLeaf);
    assert(minId.compareTo(maxId) <= 0);
    assert(minId.isValid && maxId.isValid);
    initFromBeginEnd(minId, maxId.next);
  }

  /// Creates a cell union covering the range of leaf cells from [begin] to [end) exclusive.
  void initFromBeginEnd(S2CellId begin, S2CellId end) {
    assert(begin.isLeaf);
    assert(end.isLeaf);
    assert(begin.compareTo(end) <= 0);

    _cellIds.clear();
    var nextBegin = begin;
    while (nextBegin.compareTo(end) < 0) {
      assert(nextBegin.isLeaf);

      // Find the largest cell that starts at nextBegin and ends before end.
      var nextId = nextBegin.id;
      while (!S2CellId.isFaceId(nextId) &&
          S2CellId.rangeMinId(S2CellId.parentId(nextId)) == nextBegin.id &&
          S2CellId.unsignedLessThan(S2CellId.rangeMaxId(S2CellId.parentId(nextId)), end.id)) {
        nextId = S2CellId.parentId(nextId);
      }
      final nextCellId = S2CellId(nextId);
      _cellIds.add(nextCellId);
      nextBegin = nextCellId.rangeMax.next;
    }
    // The output should already be sorted and normalized.
    assert(!normalize());
  }

  /// Returns the number of cells in the union.
  int get size => _cellIds.length;

  /// Returns the cell at the given index.
  S2CellId cellId(int i) => _cellIds[i];

  /// Returns the list of cell IDs.
  List<S2CellId> get cellIds => _cellIds;

  /// Returns true if the cell union is empty.
  bool get isEmpty => _cellIds.isEmpty;

  /// Returns true if the cell union is valid.
  ///
  /// A valid cell union has S2CellIds that are non-overlapping and sorted
  /// in increasing order.
  bool get isValid {
    for (int i = 1; i < _cellIds.length; i++) {
      if (_cellIds[i - 1].rangeMax.compareTo(_cellIds[i].rangeMin) >= 0) {
        return false;
      }
    }
    return true;
  }

  /// Returns true if the cell union is normalized.
  ///
  /// A normalized cell union is valid and has no four cells at the same level
  /// that have a common parent.
  bool get isNormalized {
    for (int i = 1; i < _cellIds.length; i++) {
      if (_cellIds[i - 1].rangeMax.compareTo(_cellIds[i].rangeMin) >= 0) {
        return false;
      }
      if (i >= 3 &&
          _areSiblings(_cellIds[i - 3], _cellIds[i - 2], _cellIds[i - 1], _cellIds[i])) {
        return false;
      }
    }
    return true;
  }

  /// Returns true if the given four cells are at the same level with a common parent.
  static bool _areSiblings(S2CellId a, S2CellId b, S2CellId c, S2CellId d) {
    // A necessary (but not sufficient) condition is that XOR of four cells is zero.
    if ((a.id ^ b.id ^ c.id) != d.id) {
      return false;
    }
    // Compute a mask that blocks out child position bits.
    int mask = d.lowestOnBit << 1;
    mask = ~(mask + (mask << 1));
    final idMasked = d.id & mask;
    return !d.isFace &&
        (a.id & mask) == idMasked &&
        (b.id & mask) == idMasked &&
        (c.id & mask) == idMasked;
  }

  /// Returns a denormalized list of cell IDs with minimum level [minLevel].
  List<S2CellId> denormalized(int minLevel) {
    final output = <S2CellId>[];
    denormalize(minLevel, 1, output);
    return output;
  }

  /// Denormalizes to [output] with minimum level [minLevel] and level step [levelMod].
  void denormalize(int minLevel, int levelMod, List<S2CellId> output) {
    assert(minLevel >= 0 && minLevel <= S2CellId.maxLevel);
    assert(levelMod >= 1 && levelMod <= 3);

    output.clear();
    for (var id in _cellIds) {
      final level = id.level;
      var newLevel = math.max(minLevel, level);
      if (levelMod > 1) {
        // Round up so that (newLevel - minLevel) is a multiple of levelMod.
        newLevel += (S2CellId.maxLevel - (newLevel - minLevel)) % levelMod;
        newLevel = math.min(S2CellId.maxLevel, newLevel);
      }
      if (newLevel == level) {
        output.add(id);
      } else {
        final end = id.childEndAtLevel(newLevel);
        for (var child = id.childBeginAtLevel(newLevel); child != end; child = child.next) {
          output.add(child);
        }
      }
    }
  }

  /// Returns true if the cell union contains the given cell id.
  ///
  /// Containment is defined with respect to regions, e.g. a cell contains
  /// its 4 children. This is a fast operation (logarithmic in size).
  bool containsCellId(S2CellId id) {
    // Binary search to find surrounding cell ids.
    int pos = _binarySearch(_cellIds, id);
    if (pos < 0) {
      pos = -pos - 1;
    }
    if (pos < _cellIds.length && _cellIds[pos].rangeMin.lessOrEquals(id)) {
      return true;
    }
    return pos != 0 && _cellIds[pos - 1].rangeMax.greaterOrEquals(id);
  }

  /// Returns true if the cell union intersects the given cell id.
  bool intersectsCellId(S2CellId id) {
    int pos = _binarySearch(_cellIds, id);
    if (pos < 0) {
      pos = -pos - 1;
    }
    if (pos < _cellIds.length && _cellIds[pos].rangeMin.lessOrEquals(id.rangeMax)) {
      return true;
    }
    return pos != 0 && _cellIds[pos - 1].rangeMax.greaterOrEquals(id.rangeMin);
  }

  /// Returns true if this cell union contains [that].
  bool containsUnion(S2CellUnion that) {
    final result = S2CellUnion();
    result.getIntersection(this, that);
    return result._cellIds.length == that._cellIds.length &&
        _listEquals(result._cellIds, that._cellIds);
  }

  /// Returns true if this cell union intersects [union].
  bool intersectsUnion(S2CellUnion union) {
    final result = S2CellUnion();
    result.getIntersection(this, union);
    return result.size > 0;
  }

  @override
  bool containsCell(S2Cell cell) => containsCellId(cell.id);

  @override
  bool containsPoint(S2Point p) => containsCellId(S2CellId.fromPoint(p));

  @override
  bool mayIntersect(S2Cell cell) => intersectsCellId(cell.id);

  /// Returns the union of two S2CellUnions.
  static S2CellUnion union(S2CellUnion x, S2CellUnion y) {
    final result = S2CellUnion();
    result.getUnion(x, y);
    return result;
  }

  /// Sets this cell union to the union of [x] and [y].
  void getUnion(S2CellUnion x, S2CellUnion y) {
    assert(!identical(x, this) && !identical(y, this));
    _cellIds.clear();
    _cellIds.addAll(x._cellIds);
    _cellIds.addAll(y._cellIds);
    normalize();
  }

  /// Gets the intersection of this cell union with a single cell id.
  void getIntersectionWithCellId(S2CellUnion x, S2CellId id) {
    assert(!identical(x, this));
    _cellIds.clear();
    if (x.containsCellId(id)) {
      _cellIds.add(id);
    } else {
      int pos = _binarySearch(x._cellIds, id.rangeMin);
      if (pos < 0) {
        pos = -pos - 1;
      }
      final idMax = id.rangeMax;
      while (pos < x._cellIds.length && x._cellIds[pos].lessOrEquals(idMax)) {
        _cellIds.add(x._cellIds[pos++]);
      }
    }
    assert(isNormalized || !x.isNormalized);
  }

  /// Returns the intersection of two S2CellUnions.
  static S2CellUnion intersection(S2CellUnion x, S2CellUnion y) {
    final result = S2CellUnion();
    result.getIntersection(x, y);
    return result;
  }

  /// Sets this cell union to the intersection of [x] and [y].
  void getIntersection(S2CellUnion x, S2CellUnion y) {
    assert(!identical(x, this) && !identical(y, this));
    _getIntersectionLists(x._cellIds, y._cellIds, _cellIds);
    assert(isNormalized || (!x.isNormalized || !y.isNormalized));
  }

  /// Gets intersection of two cell ID lists.
  static void _getIntersectionLists(
      List<S2CellId> x, List<S2CellId> y, List<S2CellId> results) {
    results.clear();
    int i = 0;
    int j = 0;
    while (i < x.length && j < y.length) {
      final xCell = x[i];
      final xMin = xCell.rangeMin;
      final yCell = y[j];
      final yMin = yCell.rangeMin;
      if (xMin.greaterThan(yMin)) {
        if (xCell.lessOrEquals(yCell.rangeMax)) {
          results.add(xCell);
          i++;
        } else {
          j = _indexedBinarySearch(y, xMin, j + 1);
          if (xCell.lessOrEquals(y[j - 1].rangeMax)) {
            --j;
          }
        }
      } else if (yMin.greaterThan(xMin)) {
        if (yCell.lessOrEquals(xCell.rangeMax)) {
          results.add(yCell);
          j++;
        } else {
          i = _indexedBinarySearch(x, yMin, i + 1);
          if (yCell.lessOrEquals(x[i - 1].rangeMax)) {
            --i;
          }
        }
      } else {
        if (xCell.lessThan(yCell)) {
          results.add(xCell);
          i++;
        } else {
          results.add(yCell);
          j++;
        }
      }
    }
  }

  /// Gets the difference of two cell unions: cells in x but not in y.
  void getDifference(S2CellUnion x, S2CellUnion y) {
    _cellIds.clear();
    for (final id in x) {
      _getDifferenceInternal(id, y);
    }
    assert(isNormalized || !x.isNormalized);
  }

  void _getDifferenceInternal(S2CellId cell, S2CellUnion y) {
    if (!y.intersectsCellId(cell)) {
      _cellIds.add(cell);
    } else if (!y.containsCellId(cell)) {
      for (int i = 0; i < 4; i++) {
        _getDifferenceInternal(cell.child(i), y);
      }
    }
  }

  /// Binary search that returns start position for lower bound.
  static int _indexedBinarySearch(List<S2CellId> list, S2CellId key, int low) {
    int high = list.length - 1;
    while (low <= high) {
      final mid = (low + high) >> 1;
      final cmp = list[mid].compareTo(key);
      if (cmp < 0) {
        low = mid + 1;
      } else if (cmp > 0) {
        high = mid - 1;
      } else {
        return mid;
      }
    }
    return low;
  }

  /// Expands the cell union by adding neighboring cells at [expandLevel].
  void expandAtLevel(int expandLevel) {
    final output = <S2CellId>[];
    final levelLsb = S2CellId.lowestOnBitForLevel(expandLevel);
    for (int i = size - 1; i >= 0; i--) {
      var id = cellId(i);
      if (id.lowestOnBit < levelLsb) {
        id = id.parentAtLevel(expandLevel);
        // Skip cells contained by this one.
        while (i > 0 && id.containsCellId(cellId(i - 1))) {
          i--;
        }
      }
      output.add(id);
      id.getAllNeighbors(expandLevel, output);
    }
    initFromCellIds(output);
  }

  /// Expands the cell union by [minRadius] with maximum level difference [maxLevelDiff].
  void expand(S1Angle minRadius, int maxLevelDiff) {
    int minLevel = S2CellId.maxLevel;
    for (final id in _cellIds) {
      minLevel = math.min(minLevel, id.level);
    }
    // Find the maximum level such that all cells are at least minRadius wide.
    int radiusLevel = S2Projections.minWidth.getMaxLevel(minRadius.radians);
    if (radiusLevel == 0 && minRadius.radians > S2Projections.minWidth.getValue(0)) {
      // The requested expansion is greater than the width of a face cell.
      expandAtLevel(0);
    }
    expandAtLevel(math.min(minLevel + maxLevelDiff, radiusLevel));
  }

  @override
  S2Cap getCapBound() {
    if (_cellIds.isEmpty) {
      return S2Cap.empty();
    }
    // Compute the approximate centroid of the region.
    S2Point centroid = S2Point.zero;
    for (final id in _cellIds) {
      final area = S2Cell.averageArea(id.level);
      centroid = centroid + id.toPoint() * area;
    }
    if (centroid == S2Point.zero) {
      centroid = S2Point.xPos;
    } else {
      centroid = centroid.normalize();
    }

    // Use the centroid as the cap axis, expand to contain all cells.
    var cap = S2Cap.fromAxisChord(centroid, S1ChordAngle.zero);
    for (final id in _cellIds) {
      cap = cap.addCap(S2Cell(id).getCapBound());
    }
    return cap;
  }

  @override
  S2LatLngRect getRectBound() {
    var rect = S2LatLngRect.empty();
    for (final id in _cellIds) {
      rect = rect.union(S2Cell(id).rectBound);
    }
    return rect;
  }

  @override
  void getCellUnionBound(List<S2CellId> cellIds) {
    cellIds.clear();
    cellIds.addAll(_cellIds);
  }

  /// Returns the number of leaf cells covered by the union.
  int get leafCellsCovered {
    int numLeaves = 0;
    for (final cellId in _cellIds) {
      final invertedLevel = S2CellId.maxLevel - cellId.level;
      numLeaves += (1 << (invertedLevel << 1));
    }
    return numLeaves;
  }

  /// Returns the average-based area of the cell union.
  double get averageBasedArea {
    return S2Cell.averageArea(S2CellId.maxLevel) * leafCellsCovered;
  }

  /// Returns the approximate area of the cell union.
  double get approxArea {
    double area = 0;
    for (final cellId in _cellIds) {
      area += S2Cell(cellId).approxArea;
    }
    return area;
  }

  /// Returns the exact area of the cell union.
  double get exactArea {
    double area = 0;
    for (final cellId in _cellIds) {
      area += S2Cell(cellId).exactArea;
    }
    return area;
  }

  /// Normalizes the cell union.
  ///
  /// Discards cells contained by other cells, replaces groups of 4 child cells
  /// by their parent, and sorts all cell IDs. Returns true if size was reduced.
  bool normalize() {
    return normalizeList(_cellIds);
  }

  /// Normalizes a list of S2CellIds.
  static bool normalizeList(List<S2CellId> ids) {
    ids.sort();
    int out = 0;
    for (int i = 0; i < ids.length; i++) {
      var id = ids[i];

      // Check if contained by previous cell.
      if (out > 0 && ids[out - 1].containsCellId(id)) {
        continue;
      }

      // Discard previous cells contained by this cell.
      while (out > 0 && id.containsCellId(ids[out - 1])) {
        out--;
      }

      // Check if last 3 elements plus id can be collapsed into parent.
      while (out >= 3) {
        if ((ids[out - 3].id ^ ids[out - 2].id ^ ids[out - 1].id) != id.id) {
          break;
        }
        int mask = id.lowestOnBit << 1;
        mask = ~(mask + (mask << 1));
        final idMasked = id.id & mask;
        if ((ids[out - 3].id & mask) != idMasked ||
            (ids[out - 2].id & mask) != idMasked ||
            (ids[out - 1].id & mask) != idMasked ||
            id.isFace) {
          break;
        }
        // Replace four children by their parent cell.
        id = id.parent();
        out -= 3;
      }
      ids[out++] = id;
    }

    final origSize = ids.length;
    final trimmed = out < origSize;
    ids.length = out;
    return trimmed;
  }

  /// Binary search returning position (or negative insertion point).
  static int _binarySearch(List<S2CellId> list, S2CellId key) {
    int low = 0;
    int high = list.length - 1;
    while (low <= high) {
      final mid = (low + high) >> 1;
      final cmp = list[mid].compareTo(key);
      if (cmp < 0) {
        low = mid + 1;
      } else if (cmp > 0) {
        high = mid - 1;
      } else {
        return mid;
      }
    }
    return -(low + 1);
  }

  /// Helper to check list equality.
  static bool _listEquals(List<S2CellId> a, List<S2CellId> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  Iterator<S2CellId> get iterator => _cellIds.iterator;

  @override
  bool operator ==(Object other) {
    if (other is! S2CellUnion) return false;
    return _listEquals(_cellIds, other._cellIds);
  }

  @override
  int get hashCode {
    int value = 17;
    for (final id in _cellIds) {
      value = 37 * value + id.hashCode;
    }
    return value;
  }

  @override
  String toString() => _cellIds.toString();
}

