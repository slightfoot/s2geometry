// Copyright 2019 Google Inc. All Rights Reserved.
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
import 's2_cell_union.dart';

/// S2CellIndex stores a collection of (cellId, label) pairs. The S2CellIds may
/// be overlapping or contain duplicate values.
///
/// Labels are 32-bit non-negative integers, and are typically used to map the
/// results of queries back to client data structures.
///
/// To build an S2CellIndex, call [add] for each (cellId, label) pair, and then
/// call the [build] method. The index is not valid until build() is called.
class S2CellIndex {
  /// A tree of (cellId, label) pairs such that if X is an ancestor of Y, then
  /// X.cellId contains Y.cellId.
  final List<_CellNode> _cellNodes = [];

  /// The last element of rangeNodes is a sentinel value.
  final List<_RangeNode> _rangeNodes = [];

  /// Returns the number of (cellId, label) pairs in the index.
  int get numCells => _cellNodes.length;

  /// Adds the given (cellId, label) pair to the index.
  ///
  /// The S2CellIds in the index may overlap (including duplicate values).
  /// Duplicate (cellId, label) pairs are also allowed.
  ///
  /// Results are undefined unless all cells are valid.
  void add(S2CellId cellId, int label) {
    assert(cellId.isValid);
    assert(label >= 0);
    _cellNodes.add(_CellNode(cellId, label, -1));
  }

  /// Convenience function that adds a collection of cells with the same label.
  void addCellUnion(S2CellUnion cellUnion, int label) {
    for (int i = 0; i < cellUnion.size; i++) {
      add(cellUnion.cellId(i), label);
    }
  }

  /// Builds the index. This method may only be called once.
  /// No iterators may be used until the index is built.
  void build() {
    // Create two deltas for each (cellId, label) pair: one to add the pair
    // to the stack (at the start of its leaf cell range), and one to remove
    // it from the stack (at the end of its leaf cell range).
    final deltas = <_Delta>[];
    for (final node in _cellNodes) {
      deltas.add(_Delta(node.cellId.rangeMin, node.cellId, node.label));
      deltas.add(_Delta(node.cellId.rangeMax.next, S2CellId.sentinel, -1));
    }

    // We also create two special deltas to ensure that a RangeNode is emitted
    // at the beginning and end of the S2CellId range.
    deltas.add(_Delta(S2CellId.begin(S2CellId.maxLevel), S2CellId.none, -1));
    deltas.add(_Delta(S2CellId.end(S2CellId.maxLevel), S2CellId.none, -1));
    deltas.sort(_Delta.compare);

    // Now walk through the deltas to build the leaf cell ranges and cell tree.
    _cellNodes.clear();
    int contents = -1;
    int i = 0;
    while (i < deltas.length) {
      // Process all the deltas associated with the current startId.
      final startId = deltas[i].startId;
      while (i < deltas.length && deltas[i].startId == startId) {
        if (deltas[i].label >= 0) {
          _cellNodes.add(_CellNode(deltas[i].cellId, deltas[i].label, contents));
          contents = _cellNodes.length - 1;
        } else if (deltas[i].cellId == S2CellId.sentinel) {
          contents = _cellNodes[contents].parent;
        }
        i++;
      }
      _rangeNodes.add(_RangeNode(startId, contents));
    }
  }

  /// Returns an iterator over the cells of this index.
  CellIterator get cells {
    assert(_rangeNodes.isNotEmpty, 'Call build() first.');
    return CellIterator._(this);
  }

  /// Returns an iterator over the ranges of this index.
  RangeIterator get ranges {
    assert(_rangeNodes.isNotEmpty, 'Call build() first.');
    return RangeIterator._(this);
  }

  /// Returns an iterator over the non-empty ranges of this index.
  NonEmptyRangeIterator get nonEmptyRanges {
    return NonEmptyRangeIterator._(this);
  }

  /// Returns an iterator over the contents of this index.
  ContentsIterator get contents {
    assert(_rangeNodes.isNotEmpty, 'Call build() first.');
    return ContentsIterator._(this);
  }

  /// Clears the index so that it can be re-used.
  void clear() {
    _cellNodes.clear();
    _rangeNodes.clear();
  }

  /// Visits all (cellId, label) pairs that intersect the given S2CellUnion
  /// and returns true, or terminates early and returns false if visitor
  /// ever returns false.
  bool visitIntersectingCells(S2CellUnion target, CellVisitor visitor) {
    if (target.isEmpty) return true;

    final contentsIter = contents;
    final range = ranges;
    int i = 0;
    while (i < target.size) {
      final id = target.cellId(i);

      // Only seek the range to this target cell when necessary.
      if (range.limitId.lessOrEquals(id.rangeMin)) {
        range.seek(id.rangeMin);
      }

      // Visit contents of this range that intersect this cell.
      while (range.startId.lessOrEquals(id.rangeMax)) {
        contentsIter.startUnion(range);
        while (!contentsIter.done) {
          if (!visitor(contentsIter.cellId, contentsIter.label)) {
            return false;
          }
          contentsIter.next();
        }
        range.next();
      }

      // Check whether the next target cell is also contained by the leaf cell
      // range that we just processed. If so, we can skip over all such cells
      // using binary search.
      i++;
      if (i != target.size && target.cellId(i).rangeMax.lessThan(range.startId)) {
        // Skip to the first target cell that extends past the previous range.
        i = _lowerBound(i + 1, target.size,
            (j) => range.startId.greaterThan(target.cellId(j)));
        if (target.cellId(i - 1).rangeMax.greaterOrEquals(range.startId)) {
          i--;
        }
      }
    }

    return true;
  }

  /// Returns the distinct sorted labels that intersect the given target.
  Labels getIntersectingLabels(S2CellUnion target) {
    final result = Labels();
    getIntersectingLabelsInto(target, result);
    result.normalize();
    return result;
  }

  /// Appends labels intersecting 'target', in unspecified order, with possible
  /// duplicates.
  void getIntersectingLabelsInto(S2CellUnion target, Labels results) {
    visitIntersectingCells(target, (cellId, label) {
      results.add(label);
      return true;
    });
  }
}

/// A function that is called with each (cellId, label) pair to be visited.
typedef CellVisitor = bool Function(S2CellId cellId, int label);

/// Binary search returning the first index i in [begin, end) where pred(i) is
/// false. If pred(i) is true for all i, returns end.
int _lowerBound(int begin, int end, bool Function(int) pred) {
  while (begin < end) {
    final mid = begin + ((end - begin) >> 1);
    if (pred(mid)) {
      begin = mid + 1;
    } else {
      end = mid;
    }
  }
  return begin;
}

/// Binary search returning the first index i in [begin, end) where pred(i) is
/// true. If pred(i) is false for all i, returns end.
int _upperBound(int begin, int end, bool Function(int) pred) {
  while (begin < end) {
    final mid = begin + ((end - begin) >> 1);
    if (pred(mid)) {
      end = mid;
    } else {
      begin = mid + 1;
    }
  }
  return begin;
}

/// A set of labels that can be grown by [S2CellIndex.getIntersectingLabelsInto]
/// and shrunk via [clear] or [normalize].
class Labels {
  List<int> _labels = [];

  void clear() {
    _labels.clear();
  }

  void add(int label) {
    _labels.add(label);
  }

  int get size => _labels.length;

  int operator [](int index) => _labels[index];

  /// Sorts the labels and removes duplicates.
  void normalize() {
    if (_labels.isEmpty) return;
    _labels.sort();
    int lastIndex = 0;
    for (int i = 1; i < _labels.length; i++) {
      if (_labels[lastIndex] != _labels[i]) {
        _labels[++lastIndex] = _labels[i];
      }
    }
    _labels = _labels.sublist(0, lastIndex + 1);
  }

  /// Returns an iterator over the labels.
  Iterator<int> get iterator => _labels.iterator;
}

/// Represents a node in the (cellId, label) tree.
class _CellNode {
  S2CellId cellId;
  int label;
  int parent;

  _CellNode(this.cellId, this.label, this.parent);

  void setFrom(_CellNode other) {
    cellId = other.cellId;
    label = other.label;
    parent = other.parent;
  }
}

/// An instruction to push or pop a (cellId, label) pair.
class _Delta {
  final S2CellId startId;
  final S2CellId cellId;
  final int label;

  _Delta(this.startId, this.cellId, this.label);

  /// Deltas are sorted first by startId, then in reverse order by cellId,
  /// and then by label.
  static int compare(_Delta a, _Delta b) {
    int result = a.startId.compareTo(b.startId);
    if (result != 0) return result;
    result = -a.cellId.compareTo(b.cellId);
    if (result != 0) return result;
    return a.label.compareTo(b.label);
  }
}

/// A RangeNode represents a range of leaf S2CellIds.
class _RangeNode {
  final S2CellId startId;
  final int contents;

  _RangeNode(this.startId, this.contents);
}

/// An iterator over all (cellId, label) pairs in an unspecified order.
class CellIterator {
  final S2CellIndex _index;
  int _offset = 0;

  CellIterator._(this._index);

  /// Returns the S2CellId of the current (cellId, label) pair.
  S2CellId get cellId {
    assert(!done);
    return _index._cellNodes[_offset].cellId;
  }

  /// Returns the label of the current (cellId, label) pair.
  int get label {
    assert(!done);
    return _index._cellNodes[_offset].label;
  }

  /// Returns true if all (cellId, label) pairs have been visited.
  bool get done => _offset == _index._cellNodes.length;

  /// Advances this iterator to the next (cellId, label) pair.
  void next() {
    assert(!done);
    _offset++;
  }
}

/// An iterator that seeks and iterates over a set of non-overlapping leaf cell
/// ranges that cover the entire sphere.
class RangeIterator {
  final S2CellIndex _index;
  int _offset = 0;

  RangeIterator._(this._index);

  /// Returns the start of the current range of leaf S2CellIds.
  S2CellId get startId => _index._rangeNodes[_offset].startId;

  /// The (non-inclusive) end of the current range of leaf S2CellIds.
  S2CellId get limitId {
    assert(!done);
    return _index._rangeNodes[_offset + 1].startId;
  }

  /// Returns true if the iterator is positioned beyond the last valid range.
  bool get done => _offset >= _index._rangeNodes.length - 1;

  /// Positions this iterator at the first range of leaf cells (if any).
  void begin() {
    _offset = 0;
  }

  /// Positions the iterator so that done() is true.
  void finish() {
    _offset = _index._rangeNodes.length - 1;
  }

  /// Advances the iterator to the next range of leaf cells.
  void next() {
    assert(!done);
    _offset++;
  }

  /// Returns false if the iterator was already positioned at the beginning,
  /// otherwise positions the iterator at the previous entry and returns true.
  bool prev() {
    if (_offset == 0) return false;
    _offset--;
    return true;
  }

  /// Positions the iterator at the range containing "target".
  void seek(S2CellId target) {
    assert(target.isLeaf);
    _offset = _upperBound(0, _index._rangeNodes.length,
            (i) => target.lessThan(_index._rangeNodes[i].startId)) -
        1;
  }

  /// Returns true if no (S2CellId, Label) pairs intersect this range.
  bool get isEmpty => _index._rangeNodes[_offset].contents == -1;

  /// Advances this iterator 'n' times and returns true, or if doing so would
  /// advance past the end, leaves iterator unmodified and returns false.
  bool advance(int n) {
    if (n >= _index._rangeNodes.length - 1 - _offset) return false;
    _offset += n;
    return true;
  }

  /// Internal access to contents for ContentsIterator.
  int get _contents => _index._rangeNodes[_offset].contents;
}

/// Like RangeIterator but only visits range nodes that overlap (cellId, label) pairs.
class NonEmptyRangeIterator extends RangeIterator {
  NonEmptyRangeIterator._(super.index) : super._();

  @override
  void begin() {
    super.begin();
    while (isEmpty && !done) {
      super.next();
    }
  }

  @override
  void next() {
    do {
      super.next();
    } while (isEmpty && !done);
  }

  @override
  bool prev() {
    while (super.prev()) {
      if (!isEmpty) return true;
    }
    // Return the iterator to its original position.
    if (isEmpty && !done) {
      next();
    }
    return false;
  }

  @override
  void seek(S2CellId target) {
    super.seek(target);
    while (isEmpty && !done) {
      super.next();
    }
  }
}

/// An iterator that visits the (cellId, label) pairs that cover a set of leaf
/// cell ranges (see RangeIterator).
///
/// Note that when multiple leaf cell ranges are visited, this class only
/// guarantees that each result will be reported at least once, i.e. duplicate
/// values may be suppressed. If you want duplicate values to be reported again,
/// be sure to call [clear] first.
class ContentsIterator {
  static const int _done = -1;

  final S2CellIndex _index;

  /// The value of range.startId from the previous call to startUnion().
  S2CellId _prevStartId = S2CellId.none;

  /// The maximum index visited during the previous call to startUnion().
  int _nodeCutoff = -1;

  /// The maximum index visited during the current call to startUnion().
  int _nextNodeCutoff = -1;

  /// A copy of the current node in the cell tree.
  final _CellNode _node = _CellNode(S2CellId.none, _done, -1);

  ContentsIterator._(this._index) {
    clear();
  }

  /// Clears all state with respect to which range(s) have been visited.
  void clear() {
    _prevStartId = S2CellId.none;
    _nodeCutoff = -1;
    _nextNodeCutoff = -1;
    _setDone();
  }

  /// Positions the ContentsIterator at the first (cellId, label) pair that
  /// covers the given leaf cell range.
  void startUnion(RangeIterator range) {
    if (range.startId.lessThan(_prevStartId)) {
      // Can't automatically eliminate duplicates.
      _nodeCutoff = -1;
    }
    _prevStartId = range.startId;
    final contents = range._contents;
    if (contents <= _nodeCutoff) {
      _setDone();
    } else {
      _node.setFrom(_index._cellNodes[contents]);
    }

    // When visiting ancestors, we can stop as soon as the node index is smaller
    // than any previously visited node index.
    _nextNodeCutoff = contents;
  }

  /// Returns the S2CellId of the current (cellId, label) pair.
  S2CellId get cellId {
    assert(!done);
    return _node.cellId;
  }

  /// Returns the label of the current (cellId, label) pair.
  int get label {
    assert(!done);
    return _node.label;
  }

  /// Returns true if all (cellId, label) pairs have been visited.
  bool get done => _node.label == _done;

  /// Advances the iterator to the next (cellId, label) pair covered by the
  /// current leaf cell range.
  void next() {
    assert(!done);
    if (_node.parent <= _nodeCutoff) {
      // We have already processed this node and its ancestors.
      _nodeCutoff = _nextNodeCutoff;
      _setDone();
    } else {
      _node.setFrom(_index._cellNodes[_node.parent]);
    }
  }

  void _setDone() {
    _node.label = _done;
  }
}

