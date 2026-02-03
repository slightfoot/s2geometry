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

import 's2_cap.dart';
import 's2_cell.dart';
import 's2_cell_id.dart';
import 's2_cell_union.dart';
import 's2_point.dart';
import 's2_projections.dart';
import 's2_region.dart';

/// An S2RegionCoverer is a class that allows arbitrary regions to be
/// approximated as unions of cells (S2CellUnion). This is useful for
/// implementing various sorts of search and precomputation operations.
///
/// Typical usage:
/// ```dart
/// final coverer = S2RegionCoverer(maxCells: 5);
/// final cap = S2Cap.fromAxisAngle(...);
/// final covering = coverer.getCovering(cap);
/// ```
///
/// This yields a cell union of at most 5 cells that is guaranteed to cover
/// the given cap (a disc-shaped region on the sphere).
class S2RegionCoverer {
  /// By default, the covering uses at most 8 cells at any level.
  static const int defaultMaxCells = 8;

  /// Face cells for initialization.
  static final List<S2Cell> _faceCells = List.generate(6, (face) => S2Cell.fromFace(face));

  final int _minLevel;
  final int _maxLevel;
  final int _levelMod;
  final int _maxCells;

  /// Creates an S2RegionCoverer with the given options.
  S2RegionCoverer({
    int minLevel = 0,
    int maxLevel = S2CellId.maxLevel,
    int levelMod = 1,
    int maxCells = defaultMaxCells,
  })  : _minLevel = minLevel.clamp(0, S2CellId.maxLevel),
        _maxLevel = maxLevel.clamp(0, S2CellId.maxLevel),
        _levelMod = levelMod.clamp(1, 3),
        _maxCells = maxCells;

  /// Returns the minimum cell level to be used.
  int get minLevel => _minLevel;

  /// Returns the maximum cell level to be used.
  int get maxLevel => _maxLevel;

  /// Returns the level mod.
  int get levelMod => _levelMod;

  /// Returns the maximum number of cells.
  int get maxCells => _maxCells;

  /// Computes a normalized cell union that covers the given region.
  S2CellUnion getCovering(S2Region region) {
    final covering = S2CellUnion();
    getCoveringInto(region, covering);
    return covering;
  }

  /// Computes a covering and stores it in the given cell union.
  void getCoveringInto(S2Region region, S2CellUnion covering) {
    final state = _ActiveCovering(this, false, region);
    state._getCoveringInternal();
    covering.initSwap(state._result);
  }

  /// Computes a list of cell ids that covers the given region.
  void getCoveringList(S2Region region, List<S2CellId> covering) {
    final tmp = getCovering(region);
    tmp.denormalize(_minLevel, _levelMod, covering);
  }

  /// Returns a normalized cell union that is contained within the given region.
  S2CellUnion getInteriorCovering(S2Region region) {
    final covering = S2CellUnion();
    getInteriorCoveringInto(region, covering);
    return covering;
  }

  /// Computes an interior covering and stores it in the given cell union.
  void getInteriorCoveringInto(S2Region region, S2CellUnion covering) {
    final state = _ActiveCovering(this, true, region);
    state._getCoveringInternal();
    covering.initSwap(state._result);
  }

  /// Computes a list of cell ids that is contained within the given region.
  void getInteriorCoveringList(S2Region region, List<S2CellId> interior) {
    final tmp = getInteriorCovering(region);
    tmp.denormalize(_minLevel, _levelMod, interior);
  }

  /// Given a connected region and a starting point, return a set of cells at
  /// the given level that cover the region.
  static void getSimpleCovering(S2Region region, S2Point start, int level, List<S2CellId> output) {
    _floodFill(region, S2CellId.fromPoint(start).parentAtLevel(level), output);
  }

  /// Like getCovering(), except that this method is much faster and the
  /// coverings are not as tight.
  void getFastCovering(S2Cap cap, List<S2CellId> results) {
    _getRawFastCovering(cap, _maxCells, results);
    normalizeCovering(results);
  }

  /// Compute a covering of the given cap.
  static void _getRawFastCovering(S2Cap cap, int maxCellsHint, List<S2CellId> covering) {
    covering.clear();

    // Find the maximum level such that the cap contains at most one cell vertex.
    int level = S2Projections.minWidth.getMaxLevel(2 * cap.angle.radians);
    level = math.min(level, S2CellId.maxLevel - 1);

    if (level == 0) {
      covering.addAll(S2CellId.faceCells);
    } else {
      final id = S2CellId.fromPoint(cap.axis);
      id.getVertexNeighbors(level, covering);
    }
  }

  /// Normalize covering so that it conforms to the current covering parameters.
  void normalizeCovering(List<S2CellId> covering) {
    // If any cells are too small, or don't satisfy levelMod(), replace with ancestors.
    if (_maxLevel < S2CellId.maxLevel || _levelMod > 1) {
      for (int i = 0; i < covering.length; i++) {
        final id = covering[i];
        final level = id.level;
        final newLevel = _adjustLevel(math.min(level, _maxLevel));
        if (newLevel != level) {
          covering[i] = id.parentAtLevel(newLevel);
        }
      }
    }

    // Sort and simplify.
    S2CellUnion.normalizeList(covering);

    // If there are still too many cells, replace two adjacent cells by their
    // lowest common ancestor.
    while (covering.length > _maxCells) {
      int bestIndex = -1;
      int bestLevel = -1;
      for (int i = 0; i + 1 < covering.length; i++) {
        int level = covering[i].getCommonAncestorLevel(covering[i + 1]);
        level = _adjustLevel(level);
        if (level > bestLevel) {
          bestLevel = level;
          bestIndex = i;
        }
      }
      if (bestLevel < _minLevel) {
        break;
      }
      covering[bestIndex] = covering[bestIndex].parentAtLevel(bestLevel);
      S2CellUnion.normalizeList(covering);
    }

    // Make sure covering satisfies minLevel() and levelMod().
    if (_minLevel > 0 || _levelMod > 1) {
      final result = S2CellUnion();
      result.initRawSwap(covering);
      result.denormalize(_minLevel, _levelMod, covering);
    }
  }

  /// Adjusts level so that it satisfies levelMod().
  int _adjustLevel(int level) {
    if (_levelMod > 1 && level > _minLevel) {
      level -= (level - _minLevel) % _levelMod;
    }
    return level;
  }

  /// Flood fill from a starting cell.
  static void _floodFill(S2Region region, S2CellId start, List<S2CellId> output) {
    final all = <S2CellId>{};
    final frontier = <S2CellId>[];
    output.clear();
    all.add(start);
    frontier.add(start);
    while (frontier.isNotEmpty) {
      final id = frontier.removeLast();
      if (!region.mayIntersect(S2Cell(id))) {
        continue;
      }
      output.add(id);

      final neighbors = List<S2CellId>.filled(4, S2CellId.none);
      id.getEdgeNeighbors(neighbors);
      for (int edge = 0; edge < 4; edge++) {
        final nbr = neighbors[edge];
        if (!all.contains(nbr)) {
          frontier.add(nbr);
          all.add(nbr);
        }
      }
    }
  }

  @override
  bool operator ==(Object other) {
    if (other is! S2RegionCoverer) return false;
    return _minLevel == other._minLevel &&
        _maxLevel == other._maxLevel &&
        _levelMod == other._levelMod &&
        _maxCells == other._maxCells;
  }

  @override
  int get hashCode => Object.hash(_minLevel, _maxLevel, _levelMod, _maxCells);
}

/// Internal candidate cell for the covering algorithm.
class _Candidate {
  S2Cell cell;
  bool isTerminal = false;
  int numChildren = 0;
  List<_Candidate?> children = [];

  _Candidate(this.cell);
}

/// Priority queue entry.
class _QueueEntry implements Comparable<_QueueEntry> {
  final int priority;
  final _Candidate candidate;

  _QueueEntry(this.priority, this.candidate);

  @override
  int compareTo(_QueueEntry other) {
    // Higher priority values come first (we negate priorities in the algorithm).
    return other.priority.compareTo(priority);
  }
}

/// Active covering state.
class _ActiveCovering {
  final S2RegionCoverer _coverer;
  final bool _interiorCovering;
  final S2Region _region;
  final List<S2CellId> _result = [];
  final List<_QueueEntry> _candidateQueue = [];

  _ActiveCovering(this._coverer, this._interiorCovering, this._region);

  /// Returns the log base 2 of the maximum number of children of a candidate.
  int get _maxChildrenShift => 2 * _coverer._levelMod;

  /// Creates a new candidate if the cell intersects the region.
  _Candidate? _newCandidate(S2Cell cell) {
    if (!_region.mayIntersect(cell)) {
      return null;
    }

    bool isTerminal = false;
    if (cell.level >= _coverer._minLevel) {
      if (_interiorCovering) {
        if (_region.containsCell(cell)) {
          isTerminal = true;
        } else if (cell.level + _coverer._levelMod > _coverer._maxLevel) {
          return null;
        }
      } else {
        if (cell.level + _coverer._levelMod > _coverer._maxLevel || _region.containsCell(cell)) {
          isTerminal = true;
        }
      }
    }
    final candidate = _Candidate(cell);
    candidate.isTerminal = isTerminal;
    if (!isTerminal) {
      candidate.children = List<_Candidate?>.filled(1 << _maxChildrenShift, null);
    }
    return candidate;
  }

  /// Process a candidate by either adding it to result or expanding it.
  void _addCandidate(_Candidate? candidate) {
    if (candidate == null) return;

    if (candidate.isTerminal) {
      _result.add(candidate.cell.id);
      return;
    }
    assert(candidate.numChildren == 0);

    // Expand one level at a time until we hit minLevel.
    final numLevels = (candidate.cell.level < _coverer._minLevel) ? 1 : _coverer._levelMod;
    final numTerminals = _expandChildren(candidate, candidate.cell, numLevels);

    if (candidate.numChildren == 0) {
      // Do nothing
    } else if (!_interiorCovering &&
        numTerminals == 1 << _maxChildrenShift &&
        candidate.cell.level >= _coverer._minLevel) {
      // Optimization: add the parent cell rather than all of its children.
      candidate.isTerminal = true;
      _addCandidate(candidate);
    } else {
      // Negate priority so smaller absolute priorities are returned first.
      final priority = -((((candidate.cell.level << _maxChildrenShift) + candidate.numChildren) <<
              _maxChildrenShift) +
          numTerminals);
      _candidateQueue.add(_QueueEntry(priority, candidate));
      _candidateQueue.sort();
    }
  }

  /// Expand children of candidate.
  int _expandChildren(_Candidate candidate, S2Cell cell, int numLevels) {
    var levels = numLevels - 1;
    final childCells = cell.subdivide();
    int numTerminals = 0;
    for (int i = 0; i < 4; i++) {
      if (levels > 0) {
        if (_region.mayIntersect(childCells[i])) {
          numTerminals += _expandChildren(candidate, childCells[i], levels);
        }
        continue;
      }
      final child = _newCandidate(childCells[i]);
      if (child != null) {
        candidate.children[candidate.numChildren++] = child;
        if (child.isTerminal) {
          numTerminals++;
        }
      }
    }
    return numTerminals;
  }

  /// Get initial candidates.
  void _getInitialCandidates() {
    if (_coverer._maxCells >= 4) {
      final cap = _region.capBound;
      int level = math.min(
        S2Projections.minWidth.getMaxLevel(2 * cap.angle.radians),
        math.min(_coverer._maxLevel, S2CellId.maxLevel - 1),
      );
      if (_coverer._levelMod > 1 && level > _coverer._minLevel) {
        level -= (level - _coverer._minLevel) % _coverer._levelMod;
      }
      if (level > 0) {
        final base = <S2CellId>[];
        final id = S2CellId.fromPoint(cap.axis);
        id.getVertexNeighbors(level, base);
        for (final cellId in base) {
          _addCandidate(_newCandidate(S2Cell(cellId)));
        }
        return;
      }
    }
    // Default: start with all six cube faces.
    for (int face = 0; face < 6; face++) {
      _addCandidate(_newCandidate(S2RegionCoverer._faceCells[face]));
    }
  }

  /// Generate the covering.
  void _getCoveringInternal() {
    assert(_candidateQueue.isEmpty && _result.isEmpty);

    _getInitialCandidates();
    while (
        _candidateQueue.isNotEmpty && (!_interiorCovering || _result.length < _coverer._maxCells)) {
      final candidate = _candidateQueue.removeAt(0).candidate;
      if (_interiorCovering ||
          candidate.cell.level < _coverer._minLevel ||
          candidate.numChildren == 1 ||
          _result.length + _candidateQueue.length + candidate.numChildren <= _coverer._maxCells) {
        // Expand this candidate into its children.
        for (int i = 0; i < candidate.numChildren; i++) {
          if (!_interiorCovering || _result.length < _coverer._maxCells) {
            _addCandidate(candidate.children[i]);
          }
        }
      } else {
        candidate.isTerminal = true;
        _addCandidate(candidate);
      }
    }
  }
}
