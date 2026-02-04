// Copyright 2015 Google Inc.
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

import 's1_angle.dart';
import 's1_chord_angle.dart';
import 's2_cap.dart';
import 's2_cell.dart';
import 's2_cell_id.dart';
import 's2_cell_union.dart';
import 's2_edge_util.dart';
import 's2_point.dart';
import 's2_point_index.dart';
import 's2_region.dart';
import 's2_region_coverer.dart';

/// Given a set of points stored in an S2PointIndex, S2ClosestPointQuery
/// provides methods that find the closest point(s) to a given query point.
class S2ClosestPointQuery<T> {
  /// The maximum number of points to process by brute force.
  static const int _maxBruteForcePoints = 150;

  /// The maximum number of points to process without subdividing further.
  static const int _maxLeafPoints = 12;

  final S2PointIndex<T> _index;
  int _maxPoints = 0x7FFFFFFF; // Integer.MAX_VALUE equivalent
  S1ChordAngle _maxDistance = S1ChordAngle.infinity;
  S2Region? _region;
  bool _useBruteForce = false;
  bool Function(Result<T>)? _filter;

  final List<S2CellId> _indexCovering = [];
  final Queue<_QueueEntry> _queue = Queue();
  late PointIndexIterator<T> _iter;
  final List<S2CellId> _regionCovering = [];
  final List<S2CellId> _maxDistanceCovering = [];
  final List<S2CellId> _intersectionWithRegion = [];
  final List<S2CellId> _intersectionWithMaxDistance = [];
  final List<PointIndexEntry<T>?> _tmpPoints =
      List.filled(_maxLeafPoints, null);
  final SplayTreeSet<Result<T>> _results = SplayTreeSet<Result<T>>();
  late S1ChordAngle _maxDistanceLimit;

  /// Constructs a new query for the given index.
  S2ClosestPointQuery(this._index) {
    reset();
  }

  /// Resets the query state. Call after modifying the underlying index.
  void reset() {
    _iter = _index.iterator;
    useBruteForce(_index.numPoints <= _maxBruteForcePoints);
  }

  /// Returns the underlying S2PointIndex.
  S2PointIndex<T> get index => _index;

  /// Returns the max number of closest points to find.
  int get maxPoints => _maxPoints;

  /// Sets a new max number of closest points to find.
  void setMaxPoints(int maxPoints) {
    if (maxPoints < 1) {
      throw ArgumentError('Must be at least 1.');
    }
    _maxPoints = maxPoints;
  }

  /// Sets the maximum distance for conservative comparison.
  void setConservativeMaxDistance(S1ChordAngle maxDistance) {
    setMaxDistanceChord(maxDistance
        .plusError(S2EdgeUtil.getUpdateMinDistanceMaxError(maxDistance))
        .successor);
  }

  /// Sets the maximum distance for conservative comparison (S1Angle version).
  void setConservativeMaxDistanceAngle(S1Angle maxDistance) {
    setConservativeMaxDistance(S1ChordAngle.fromS1Angle(maxDistance));
  }

  /// Sets maximum distance inclusive.
  void setInclusiveMaxDistance(S1ChordAngle maxDistance) {
    setMaxDistanceChord(maxDistance.successor);
  }

  /// Sets maximum distance inclusive (S1Angle version).
  void setInclusiveMaxDistanceAngle(S1Angle maxDistance) {
    setInclusiveMaxDistance(S1ChordAngle.fromS1Angle(maxDistance));
  }

  /// Sets the maximum distance.
  void setMaxDistanceChord(S1ChordAngle maxDistance) {
    _maxDistance = maxDistance;
  }

  /// Sets the maximum distance (S1Angle version).
  void setMaxDistance(S1Angle maxDistance) {
    _maxDistance = S1ChordAngle.fromS1Angle(maxDistance);
  }

  /// Sets a filter to apply to each point.
  void setFilter(bool Function(Result<T>) filter) {
    _filter = filter;
  }

  /// Returns the maximum distance.
  S1ChordAngle get maxDistance => _maxDistance;

  /// Returns the region constraint, if any.
  S2Region? get region => _region;

  /// Sets or clears the region constraint.
  void setRegion(S2Region? region) {
    _region = region;
  }

  /// Sets whether to use brute force search.
  void useBruteForce(bool useBruteForce) {
    _useBruteForce = useBruteForce;
    if (!_useBruteForce) {
      _initIndexCovering();
    }
  }

  /// Returns the closest points to target.
  List<Result<T>> findClosestPoints(S2Point target) {
    _findClosestPointsToTarget(_PointTarget(target));
    return _toList();
  }

  /// Adds closest points to target to the given list.
  void findClosestPointsToList(List<Result<T>> results, S2Point target) {
    _findClosestPointsToTarget(_PointTarget(target));
    results.addAll(_toList());
  }

  /// Returns the closest point to target, or null if none found.
  Result<T>? findClosestPoint(S2Point target) {
    final oldMaxPoints = _maxPoints;
    _maxPoints = 1;
    final results = findClosestPoints(target);
    _maxPoints = oldMaxPoints;
    return results.isEmpty ? null : results.first;
  }

  /// Returns the closest points to the edge AB.
  List<Result<T>> findClosestPointsToEdge(S2Point a, S2Point b) {
    _findClosestPointsToTarget(_EdgeTarget(a, b));
    return _toList();
  }

  /// Adds closest points to edge AB to the given list.
  void findClosestPointsToEdgeToList(
      List<Result<T>> results, S2Point a, S2Point b) {
    _findClosestPointsToTarget(_EdgeTarget(a, b));
    results.addAll(_toList());
  }

  List<Result<T>> _toList() {
    final list = <Result<T>>[];
    // Results are sorted in descending order by distance (largest first).
    // We need to reverse them to get ascending order.
    for (final result in _results.toList().reversed) {
      list.add(result);
    }
    _results.clear();
    return list;
  }

  void _findClosestPointsToTarget(_Target target) {
    _maxDistanceLimit = _maxDistance;
    if (_useBruteForce) {
      _findClosestPointsBruteForce(target);
    } else {
      _findClosestPointsOptimized(target);
    }
  }

  void _findClosestPointsBruteForce(_Target target) {
    _iter.restart();
    while (!_iter.done) {
      _maybeAddResult(_iter.entry!, target);
      _iter.next();
    }
  }

  void _findClosestPointsOptimized(_Target target) {
    _initQueue(target);
    while (_queue.isNotEmpty) {
      final entry = _queue.removeFirst();
      if (entry.distance.compareTo(_maxDistanceLimit) >= 0) {
        _queue.clear();
        break;
      }
      var child = entry.id.childBegin;
      var seek = true;
      for (int i = 0; i < 4; i++) {
        seek = _addCell(child, _iter, seek, target);
        child = child.next;
      }
    }
  }

  void _maybeAddResult(PointIndexEntry<T> entry, _Target target) {
    final distance = target.getMinDistance(entry.point!, _maxDistanceLimit);
    if (identical(distance, _maxDistanceLimit)) {
      return;
    }
    if (_region != null && !_region!.containsPoint(entry.point!)) {
      return;
    }

    final result = Result<T>(distance, entry);
    if (_filter != null && !_filter!(result)) {
      return;
    }

    if (_results.length >= _maxPoints) {
      _results.remove(_results.first); // Remove furthest (largest distance)
    }
    _results.add(result);
    if (_results.length >= _maxPoints) {
      _maxDistanceLimit = _results.first.distance;
    }
  }

  void _initIndexCovering() {
    _indexCovering.clear();
    _iter.restart();
    if (_iter.done) return;

    final nextIt = _iter.copy();
    var indexNext = nextIt.cellId;
    final lastIt = _iter.copy();
    lastIt.finish();
    lastIt.prev();
    final indexLast = lastIt.cellId;

    if (indexNext != indexLast) {
      final level = indexNext.getCommonAncestorLevel(indexLast) + 1;
      final coverLast = indexLast.parentAtLevel(level);
      var cover = indexNext.parentAtLevel(level);

      while (cover != coverLast && !nextIt.done) {
        final coverMax = cover.rangeMax;
        if (nextIt.cellId.compareTo(coverMax) <= 0) {
          final prevId = nextIt.cellId;
          nextIt.seek(coverMax.next);
          final cellLast = nextIt.copy();
          cellLast.prev();
          _coverRange(prevId, cellLast.cellId);
        }
        cover = cover.next;
      }
    }
    _coverRange(indexNext, indexLast);
  }

  void _coverRange(S2CellId firstId, S2CellId lastId) {
    final level = firstId.getCommonAncestorLevel(lastId);
    _indexCovering.add(firstId.parentAtLevel(level));
  }

  void _initQueue(_Target target) {
    _queue.clear();

    // Optimization: If searching for just the closest point, look at neighbors.
    if (_maxPoints == 1) {
      _iter.seek(S2CellId.fromPoint(target.center));
      if (!_iter.done) {
        _maybeAddResult(_iter.entry!, target);
      }
      if (!_iter.atBegin) {
        _iter.prev();
        _maybeAddResult(_iter.entry!, target);
      }
    }

    // Start with covering of indexed points, intersected with region and max distance.
    var initialCells = _indexCovering;
    final coverer = S2RegionCoverer(maxCells: 4);

    if (_region != null) {
      _regionCovering.clear();
      final regionCoveringUnion = coverer.getCovering(_region!);
      _regionCovering.addAll(regionCoveringUnion.cellIds);
      _intersectionWithRegion.clear();
      final indexUnion = S2CellUnion.fromCellIds(_indexCovering);
      final regionUnion = S2CellUnion.fromCellIds(_regionCovering);
      final intersectionUnion = S2CellUnion.intersection(indexUnion, regionUnion);
      _intersectionWithRegion.addAll(intersectionUnion.cellIds);
      initialCells = _intersectionWithRegion;
    }

    if (!_maxDistanceLimit.isInfinity) {
      final searchCap = S2Cap.fromAxisAngle(
          target.center,
          S1Angle.radians(target.radius + _maxDistanceLimit.toAngle().radians));
      _maxDistanceCovering.clear();
      coverer.getFastCovering(searchCap, _maxDistanceCovering);
      _intersectionWithMaxDistance.clear();
      final initialUnion = S2CellUnion.fromCellIds(initialCells);
      final maxDistUnion = S2CellUnion.fromCellIds(_maxDistanceCovering);
      final intersectionUnion = S2CellUnion.intersection(initialUnion, maxDistUnion);
      _intersectionWithMaxDistance.addAll(intersectionUnion.cellIds);
      initialCells = _intersectionWithMaxDistance;
    }

    _iter.restart();
    for (int i = 0; i < initialCells.length && !_iter.done; i++) {
      final id = initialCells[i];
      final seek = _iter.cellId.compareTo(id.rangeMin) <= 0;
      _addCell(id, _iter, seek, target);
    }
  }

  bool _addCell(
      S2CellId id, PointIndexIterator<T> iter, bool seek, _Target target) {
    if (seek) {
      iter.seek(id.rangeMin);
    }
    if (id.isLeaf) {
      while (!iter.done && iter.cellId == id) {
        _maybeAddResult(iter.entry!, target);
        iter.next();
      }
      return false;
    }
    final last = id.rangeMax;
    int numPoints = 0;
    while (!iter.done && iter.cellId.compareTo(last) <= 0) {
      if (numPoints == _maxLeafPoints) {
        final cell = S2Cell(id);
        final distance = target.getDistanceToCell(cell);
        if (distance.compareTo(_maxDistanceLimit) < 0) {
          if (_region == null || _region!.mayIntersect(cell)) {
            _queue.addLast(_QueueEntry(distance, id));
          }
        }
        return true;
      }
      _tmpPoints[numPoints++] = iter.entry;
      iter.next();
    }
    for (int i = 0; i < numPoints; i++) {
      _maybeAddResult(_tmpPoints[i]!, target);
    }
    return false;
  }
}

/// A query result paired with the distance to the query target.
class Result<T> implements Comparable<Result<T>> {
  final S1ChordAngle _distance;
  final PointIndexEntry<T> _entry;

  Result(this._distance, this._entry);

  S1ChordAngle get distance => _distance;
  PointIndexEntry<T> get entry => _entry;

  @override
  int get hashCode => _entry.hashCode;

  @override
  bool operator ==(Object other) {
    if (other is Result<T>) {
      return _entry == other._entry;
    }
    return false;
  }

  @override
  String toString() => '${_distance.toAngle().degrees}: $_entry';

  @override
  int compareTo(Result<T> other) {
    // Descending order (largest distance first) for the SplayTreeSet.
    final cmp = other._distance.compareTo(_distance);
    if (cmp != 0) return cmp;
    // Tie-break by cell ID to ensure unique entries with same distance
    final cellCmp = _entry.cellId.compareTo(other._entry.cellId);
    if (cellCmp != 0) return cellCmp;
    // Final tie-break by point coordinates
    if (_entry.point != null && other._entry.point != null) {
      final pointCmp = _entry.point!.compareTo(other._entry.point!);
      if (pointCmp != 0) return pointCmp;
    }
    // Use hashCode as last resort to distinguish entries
    return _entry.hashCode.compareTo(other._entry.hashCode);
  }
}

/// A queued cell waiting to be processed.
class _QueueEntry implements Comparable<_QueueEntry> {
  final S1ChordAngle distance;
  final S2CellId id;

  _QueueEntry(this.distance, this.id);

  @override
  int compareTo(_QueueEntry other) {
    // Ascending order (smallest distance first).
    return distance.compareTo(other.distance);
  }
}

/// A kind of query target.
abstract class _Target {
  S2Point get center;
  S1ChordAngle getDistanceToCell(S2Cell cell);
  double get radius;
  S1ChordAngle getMinDistance(S2Point point, S1ChordAngle distance);
}

/// A point query target.
class _PointTarget implements _Target {
  final S2Point _point;

  _PointTarget(this._point);

  @override
  S2Point get center => _point;

  @override
  double get radius => 0;

  @override
  S1ChordAngle getMinDistance(S2Point x, S1ChordAngle minDist) {
    final angle = S1ChordAngle(x, _point);
    return angle.compareTo(minDist) > 0 ? minDist : angle;
  }

  @override
  S1ChordAngle getDistanceToCell(S2Cell cell) {
    return cell.getDistance(_point);
  }
}

/// An edge query target.
class _EdgeTarget implements _Target {
  final S2Point _a;
  final S2Point _b;

  _EdgeTarget(this._a, this._b);

  @override
  S2Point get center => _a.add(_b).normalize();

  @override
  double get radius => 0.5 * _a.angle(_b);

  @override
  S1ChordAngle getMinDistance(S2Point x, S1ChordAngle minDist) {
    return S2EdgeUtil.updateMinDistance(x, _a, _b, minDist);
  }

  @override
  S1ChordAngle getDistanceToCell(S2Cell cell) {
    return cell.getDistanceToEdge(_a, _b);
  }
}