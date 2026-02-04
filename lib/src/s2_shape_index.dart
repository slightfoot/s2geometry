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

import 'dart:math' as math;
import 'dart:typed_data';

import 'r1_interval.dart';
import 'r2_rect.dart';
import 'r2_vector.dart';
import 's2.dart';
import 's2_cell_id.dart';
import 's2_edge_util.dart';
import 's2_iterator.dart';
import 's2_padded_cell.dart';
import 's2_point.dart';
import 's2_projections.dart';
import 's2_shape.dart';

/// Edge clipping error in UV coordinates.
const double _edgeClipErrorUvCoord = 2.25 * S2.dblEpsilon;

/// The amount in UV coordinates by which cells are "padded" to compensate for
/// numerical errors when clipping line segments to cell boundaries.
final double cellPadding =
    2 * (S2EdgeUtil.FACE_CLIP_ERROR_UV_COORD + _edgeClipErrorUvCoord);

/// Default maximum number of edges per cell.
const int defaultMaxEdgesPerCell = 10;

/// Default maximum cell size relative to an edge's length.
const double defaultCellSizeToLongEdgeRatio = 1.0;

/// Default minimum fraction of 'short' edges required to subdivide.
const double defaultMinShortEdgeFraction = 0.2;

/// Options that affect construction of the S2ShapeIndex.
class S2ShapeIndexOptions {
  /// Maximum number of edges per cell (default 10).
  int maxEdgesPerCell = defaultMaxEdgesPerCell;

  /// Cell size to long edge ratio (default 1.0).
  double cellSizeToLongEdgeRatio = defaultCellSizeToLongEdgeRatio;

  /// Minimum short edge fraction (default 0.2).
  double minShortEdgeFraction = defaultMinShortEdgeFraction;
}

/// A vector of sorted unique edge IDs.
abstract class EdgeIds {
  /// Returns the number of edges.
  int get numEdges;

  /// Returns the edge at the given index.
  int edge(int index);
}

/// S2ClippedShape represents the part of a shape that intersects an S2Cell.
/// It consists of the set of edge ids that intersect that cell, and a boolean
/// indicating whether the center of the cell is inside the shape.
abstract class S2ClippedShape extends S2ShapeIndexCell implements EdgeIds {
  /// Returns the shape ID of the shape this clipped shape was clipped from.
  int get shapeId;

  /// Returns whether the center of the S2CellId is inside the shape.
  bool get containsCenter;

  @override
  int get numShapes => 1;

  @override
  S2ClippedShape clipped(int i) {
    assert(i == 0);
    return this;
  }

  /// Returns whether this clipped shape contains the given edge id.
  bool containsEdge(int edgeId) {
    for (int e = 0; e < numEdges; e++) {
      if (edge(e) == edgeId) return true;
    }
    return false;
  }

  /// Creates an S2ClippedShape with the given parameters.
  static S2ClippedShape create(
    S2CellId? cellId,
    int shapeId,
    bool containsCenter,
    int offset,
    int count,
  ) {
    return _EdgeRangeClippedShape(
      cellId?.id,
      shapeId,
      containsCenter,
      offset,
      count,
    );
  }

  /// Creates an S2ClippedShape for a contained cell (no edges).
  static S2ClippedShape createContained(S2CellId? cellId, int shapeId) {
    return _ContainedClippedShape(cellId?.id, shapeId);
  }

  /// Creates an S2ClippedShape with a single edge.
  static S2ClippedShape createOneEdge(
    S2CellId? cellId,
    int shapeId,
    bool containsCenter,
    int edgeId,
  ) {
    return _OneEdgeClippedShape(cellId?.id, shapeId, containsCenter, edgeId);
  }

  /// Creates an S2ClippedShape with multiple non-contiguous edges.
  static S2ClippedShape createManyEdges(
    S2CellId? cellId,
    int shapeId,
    bool containsCenter,
    List<int> edges,
  ) {
    return _ManyEdgesClippedShape(
      cellId?.id,
      shapeId,
      containsCenter,
      Int32List.fromList(edges),
    );
  }
}

/// A clipped shape for a contained cell (no edges, containsCenter is true).
class _ContainedClippedShape extends S2ClippedShape {
  final int? _cellId;
  final int _shapeId;

  _ContainedClippedShape(this._cellId, this._shapeId);

  @override
  int get id => _cellId ?? (throw UnsupportedError('No cell ID'));

  @override
  int get shapeId => _shapeId;

  @override
  bool get containsCenter => true;

  @override
  int get numEdges => 0;

  @override
  int edge(int i) => throw RangeError.index(i, this, 'i', null, 0);
}

/// A clipped shape with a single edge.
class _OneEdgeClippedShape extends S2ClippedShape {
  final int? _cellId;
  final int _shapeId;
  final bool _containsCenter;
  final int _edgeId;

  _OneEdgeClippedShape(
    this._cellId,
    this._shapeId,
    this._containsCenter,
    this._edgeId,
  );

  @override
  int get id => _cellId ?? (throw UnsupportedError('No cell ID'));

  @override
  int get shapeId => _shapeId;

  @override
  bool get containsCenter => _containsCenter;

  @override
  int get numEdges => 1;

  @override
  int edge(int i) => _edgeId;
}

/// A clipped shape with multiple non-contiguous edges.
class _ManyEdgesClippedShape extends S2ClippedShape {
  final int? _cellId;
  final int _shapeId;
  final bool _containsCenter;
  final Int32List _edges;

  _ManyEdgesClippedShape(
    this._cellId,
    this._shapeId,
    this._containsCenter,
    this._edges,
  );

  @override
  int get id => _cellId ?? (throw UnsupportedError('No cell ID'));

  @override
  int get shapeId => _shapeId;

  @override
  bool get containsCenter => _containsCenter;

  @override
  int get numEdges => _edges.length;

  @override
  int edge(int i) => _edges[i];
}

/// A clipped shape with a contiguous range of edges.
class _EdgeRangeClippedShape extends S2ClippedShape {
  final int? _cellId;
  final int _shapeId;
  final bool _containsCenter;
  final int _offset;
  final int _count;

  _EdgeRangeClippedShape(
    this._cellId,
    this._shapeId,
    this._containsCenter,
    this._offset,
    this._count,
  );

  @override
  int get id => _cellId ?? (throw UnsupportedError('No cell ID'));

  @override
  int get shapeId => _shapeId;

  @override
  bool get containsCenter => _containsCenter;

  @override
  int get numEdges => _count;

  @override
  int edge(int i) => _offset + i;
}

/// S2ShapeIndexCell contains the set of clipped shapes within a particular
/// index cell, sorted in increasing order of shape id.
abstract class S2ShapeIndexCell implements S2IteratorEntry {
  /// Returns the number of clipped shapes in this cell.
  int get numShapes;

  /// Returns the clipped shape at the given index.
  S2ClippedShape clipped(int i);

  /// Returns a list view of the clipped shapes in this cell.
  List<S2ClippedShape> get clippedShapes {
    return List.generate(numShapes, (i) => clipped(i));
  }

  /// Returns the number of clipped edges in this cell.
  int get numEdges {
    int count = 0;
    for (int i = 0; i < numShapes; i++) {
      count += clipped(i).numEdges;
    }
    return count;
  }

  /// Returns the clipped shape for the given shape id, or null if not found.
  S2ClippedShape? findClipped(int shapeId) {
    for (int i = 0; i < numShapes; i++) {
      final clippedShape = clipped(i);
      if (clippedShape.shapeId == shapeId) {
        return clippedShape;
      }
    }
    return null;
  }

  /// Creates a cell with the given clipped shapes.
  static S2ShapeIndexCell create(List<S2ClippedShape> shapes) {
    switch (shapes.length) {
      case 1:
        return shapes[0];
      case 2:
        return _BinaryCell(shapes[0], shapes[1]);
      default:
        return _MultiCell(shapes);
    }
  }
}

/// A cell with exactly two clipped shapes.
class _BinaryCell extends S2ShapeIndexCell {
  final S2ClippedShape _shape1;
  final S2ClippedShape _shape2;

  _BinaryCell(this._shape1, this._shape2);

  @override
  int get id => _shape1.id;

  @override
  int get numShapes => 2;

  @override
  S2ClippedShape clipped(int i) {
    switch (i) {
      case 0:
        return _shape1;
      case 1:
        return _shape2;
      default:
        throw RangeError.index(i, this, 'i', null, 2);
    }
  }
}

/// A cell with multiple clipped shapes.
class _MultiCell extends S2ShapeIndexCell {
  final List<S2ClippedShape> _shapes;

  _MultiCell(this._shapes);

  @override
  int get id => _shapes[0].id;

  @override
  int get numShapes => _shapes.length;

  @override
  S2ClippedShape clipped(int i) => _shapes[i];
}

/// S2ShapeIndex is a spatial index that indexes shapes (collections of edges)
/// for fast point-in-polygon and intersection queries.
///
/// The index is built lazily when first accessed via [iterator].
class S2ShapeIndex {
  /// The options for this index.
  final S2ShapeIndexOptions options;

  /// The shapes in this index.
  final List<S2Shape?> _shapes = [];

  /// The indexed cells, sorted by cell id.
  List<S2ShapeIndexCell> _cells = [];

  /// The index of the first shape that has been queued but not processed.
  int _pendingInsertionsBegin = 0;

  /// True if the index is up to date.
  bool _isIndexFresh = true;

  /// Creates an S2ShapeIndex with default options.
  S2ShapeIndex() : options = S2ShapeIndexOptions();

  /// Creates an S2ShapeIndex with the given options.
  S2ShapeIndex.withOptions(this.options);

  /// Creates an S2ShapeIndex containing the given shapes.
  factory S2ShapeIndex.fromShapes(List<S2Shape> shapes) {
    final index = S2ShapeIndex();
    for (final shape in shapes) {
      index.add(shape);
    }
    return index;
  }

  /// Returns the shapes in this index.
  List<S2Shape?> get shapes => List.unmodifiable(_shapes);

  /// Returns the shape at the given index, or null if removed.
  S2Shape? shape(int shapeId) => _shapes[shapeId];

  /// Returns the number of shapes in this index.
  int get numShapes => _shapes.length;

  /// Adds a shape to this index. Returns the shape id.
  int add(S2Shape shape) {
    final shapeId = _shapes.length;
    _shapes.add(shape);
    _isIndexFresh = false;
    return shapeId;
  }

  /// Returns true if the index is up to date.
  bool get isFresh => _isIndexFresh;

  /// Clears the index and resets it to its original state.
  void reset() {
    _cells = [];
    _shapes.clear();
    _isIndexFresh = true;
    _pendingInsertionsBegin = 0;
  }

  /// Returns an iterator over the cells of this index.
  /// Builds the index if necessary.
  ListS2Iterator<S2ShapeIndexCell> iterator() {
    applyUpdates();
    return ListS2Iterator(_cells);
  }

  /// Ensures pending updates have been applied.
  void applyUpdates() {
    if (_isIndexFresh) return;

    assert(_cells.isEmpty, 'Incremental updates not supported yet');

    // Create lists to hold edges for each face
    final allEdges = List<List<_FaceEdge>>.generate(6, (_) => []);

    // Create state for index building
    final state = _IndexState(options, _shapes);

    // Add edges from each shape
    for (int i = _pendingInsertionsBegin; i < _shapes.length; i++) {
      _addShapeEdges(i, allEdges, state.tracker);
    }

    // Build cells for each face
    for (int face = 0; face < 6; face++) {
      _updateFaceEdges(face, allEdges[face], state);
      allEdges[face] = []; // Free memory
    }

    _cells = state.cells;
    _pendingInsertionsBegin = _shapes.length;
    _isIndexFresh = true;
  }

  /// Adds all edges from the given shape to the face edge lists.
  void _addShapeEdges(
    int shapeId,
    List<List<_FaceEdge>> allEdges,
    _InteriorTracker tracker,
  ) {
    final shape = _shapes[shapeId];
    if (shape == null) return;

    final hasInterior = shape.hasInterior;
    if (hasInterior) {
      tracker.addShape(shapeId, shape);
    }

    final numEdges = shape.numEdges;
    final edge = MutableEdge();
    final a = R2Vector(0, 0);
    final b = R2Vector(0, 0);
    final ratio = options.cellSizeToLongEdgeRatio;

    for (int e = 0; e < numEdges; e++) {
      shape.getEdge(e, edge);
      final va = edge.a!;
      final vb = edge.b!;

      if (hasInterior) {
        tracker.testEdge(shapeId, va, vb);
      }

      // Fast path: both endpoints on same face
      final aFace = S2Projections.xyzToFace(va);
      if (aFace == S2Projections.xyzToFace(vb)) {
        S2Projections.validFaceXyzToUvInto(aFace, va, a);
        S2Projections.validFaceXyzToUvInto(aFace, vb, b);
        final kMaxUV = 1 - cellPadding;
        if (a.x.abs() <= kMaxUV &&
            a.y.abs() <= kMaxUV &&
            b.x.abs() <= kMaxUV &&
            b.y.abs() <= kMaxUV) {
          allEdges[aFace].add(_FaceEdge(shapeId, e, va, vb, a.x, a.y, b.x, b.y, ratio));
          continue;
        }
      }

      // Slow path: clip to each face
      _clipEdgeToAllFaces(shapeId, e, va, vb, ratio, allEdges);
    }
  }

  /// Clips an edge to all faces it intersects.
  void _clipEdgeToAllFaces(
    int shapeId,
    int edgeId,
    S2Point va,
    S2Point vb,
    double ratio,
    List<List<_FaceEdge>> allEdges,
  ) {
    final aUv = R2Vector(0, 0);
    final bUv = R2Vector(0, 0);
    // Clip edge to each face using S2EdgeUtil.clipToPaddedFace
    for (int face = 0; face < 6; face++) {
      if (S2EdgeUtil.clipToPaddedFace(va, vb, face, cellPadding, aUv, bUv)) {
        allEdges[face].add(_FaceEdge(
          shapeId,
          edgeId,
          va,
          vb,
          aUv.x,
          aUv.y,
          bUv.x,
          bUv.y,
          ratio,
        ));
      }
    }
  }

  /// Updates the index for edges on a single face.
  void _updateFaceEdges(int face, List<_FaceEdge> faceEdges, _IndexState state) {
    if (faceEdges.isEmpty) return;

    // Sort edges by shape id, then edge id
    faceEdges.sort((a, b) {
      final cmp = a.shapeId.compareTo(b.shapeId);
      return cmp != 0 ? cmp : a.edgeId.compareTo(b.edgeId);
    });

    // Create clipped edges
    final clippedEdges = <_ClippedEdge>[];
    for (final faceEdge in faceEdges) {
      final clipped = _ClippedEdge(faceEdge);
      clippedEdges.add(clipped);
    }

    // Process the face
    final pcell = S2PaddedCell(S2CellId.fromFace(face), cellPadding);
    _updateEdges(pcell, clippedEdges, state);
  }

  /// Recursively updates the index for a cell and its children.
  void _updateEdges(
    S2PaddedCell pcell,
    List<_ClippedEdge> edges,
    _IndexState state,
  ) {
    // If we can make a cell from these edges, we're done.
    if (_makeIndexCell(pcell, edges, state)) {
      return;
    }

    // Otherwise, subdivide the cell.
    final middle = pcell.middle();
    final edges00 = <_ClippedEdge>[];
    final edges01 = <_ClippedEdge>[];
    final edges10 = <_ClippedEdge>[];
    final edges11 = <_ClippedEdge>[];

    for (final edge in edges) {
      if (edge.bound.x.hi <= middle.x.lo) {
        _clipVAxis(edge, middle.y, edges00, edges01);
      } else if (edge.bound.x.lo >= middle.x.hi) {
        _clipVAxis(edge, middle.y, edges10, edges11);
      } else if (edge.bound.y.hi <= middle.y.lo) {
        edges00.add(_clipUBound(edge, true, middle.x.hi));
        edges10.add(_clipUBound(edge, false, middle.x.lo));
      } else if (edge.bound.y.lo >= middle.y.hi) {
        edges01.add(_clipUBound(edge, true, middle.x.hi));
        edges11.add(_clipUBound(edge, false, middle.x.lo));
      } else {
        final left = _clipUBound(edge, true, middle.x.hi);
        _clipVAxis(left, middle.y, edges00, edges01);
        final right = _clipUBound(edge, false, middle.x.lo);
        _clipVAxis(right, middle.y, edges10, edges11);
      }
    }

    // Process children in S2CellId order
    final ijEdges = [edges00, edges01, edges10, edges11];
    for (int pos = 0; pos < 4; pos++) {
      final childEdges = ijEdges[S2.posToIJ(pcell.orientation, pos)];
      if (childEdges.isNotEmpty || state.tracker.focusCount > 0) {
        final childCell = pcell.childAtPos(pos);
        _updateEdges(childCell, childEdges, state);
      }
    }
  }

  /// Creates an index cell if appropriate, returns true if created.
  bool _makeIndexCell(
    S2PaddedCell pcell,
    List<_ClippedEdge> edges,
    _IndexState state,
  ) {
    if (edges.isEmpty && state.tracker.focusCount == 0) {
      return true;
    }

    // Check if we need to subdivide
    if (edges.length > options.maxEdgesPerCell) {
      final maxShortEdges = math.max(
        options.maxEdgesPerCell,
        (options.minShortEdgeFraction * (edges.length + state.tracker.focusCount)).toInt(),
      );
      int count = 0;
      for (final edge in edges) {
        if (pcell.level < edge.orig.maxLevel) {
          count++;
          if (count > maxShortEdges) {
            return false;
          }
        }
      }
    }

    // Move tracker to cell center
    if (state.tracker.isActive && edges.isNotEmpty) {
      if (!state.tracker.atCellId(pcell.id)) {
        state.tracker.moveTo(pcell.getEntryVertex());
      }
      state.tracker.drawTo(pcell.getCenter());
      _testClippedEdges(edges, state);
    }

    // Build the cell
    S2CellId? cellId = pcell.id;
    final clippedShapes = <S2ClippedShape>[];
    int edgesIndex = 0;
    int trackerIndex = 0;
    final numEdges = edges.length;
    final nextShapeId = _shapes.length;

    while (edgesIndex < numEdges || trackerIndex < state.tracker.focusCount) {
      final edgeShapeId = edgesIndex < numEdges
          ? edges[edgesIndex].orig.shapeId
          : nextShapeId;
      final trackerShapeId = trackerIndex < state.tracker.focusCount
          ? state.tracker._focusedShapes[trackerIndex]
          : nextShapeId;

      if (trackerShapeId < edgeShapeId) {
        // Cell is entirely inside this shape
        clippedShapes.add(S2ClippedShape.createContained(cellId, trackerShapeId));
        cellId = null;
        trackerIndex++;
      } else {
        // Collect edges for this shape
        final firstEdge = edgesIndex;
        while (edgesIndex < numEdges &&
            edges[edgesIndex].orig.shapeId == edgeShapeId) {
          edgesIndex++;
        }
        final containsCenter = trackerShapeId == edgeShapeId;
        final edgeIds = <int>[];
        for (int i = firstEdge; i < edgesIndex; i++) {
          edgeIds.add(edges[i].orig.edgeId);
        }
        if (edgeIds.length == 1) {
          clippedShapes.add(S2ClippedShape.createOneEdge(
            cellId,
            edgeShapeId,
            containsCenter,
            edgeIds[0],
          ));
        } else {
          clippedShapes.add(S2ClippedShape.createManyEdges(
            cellId,
            edgeShapeId,
            containsCenter,
            edgeIds,
          ));
        }
        cellId = null;
        if (containsCenter) {
          trackerIndex++;
        }
      }
    }

    // Add the cell
    state.cells.add(S2ShapeIndexCell.create(clippedShapes));

    // Move tracker to exit vertex
    if (state.tracker.isActive && edges.isNotEmpty) {
      state.tracker.drawTo(pcell.getExitVertex());
      _testClippedEdges(edges, state);
      state.tracker.doneCellId(pcell.id);
    }

    return true;
  }

  void _testClippedEdges(List<_ClippedEdge> edges, _IndexState state) {
    for (final edge in edges) {
      final shape = _shapes[edge.orig.shapeId];
      if (shape != null && shape.hasInterior) {
        state.tracker.testEdge(edge.orig.shapeId, edge.orig.va, edge.orig.vb);
      }
    }
  }

  _ClippedEdge _clipUBound(_ClippedEdge edge, bool uEnd, double u) {
    if (!uEnd) {
      if (edge.bound.x.lo >= u) return edge;
    } else {
      if (edge.bound.x.hi <= u) return edge;
    }

    final e = edge.orig;
    final v = edge.bound.y.clampPoint(
      S2EdgeUtil.interpolateDouble(u, e.ax, e.bx, e.ay, e.by),
    );
    final vEnd = ((e.ax > e.bx) != (e.ay > e.by)) ^ uEnd;
    return _updateBound(edge, uEnd, u, vEnd, v);
  }

  _ClippedEdge _clipVBound(_ClippedEdge edge, bool vEnd, double v) {
    if (!vEnd) {
      if (edge.bound.y.lo >= v) return edge;
    } else {
      if (edge.bound.y.hi <= v) return edge;
    }

    final e = edge.orig;
    final u = edge.bound.x.clampPoint(
      S2EdgeUtil.interpolateDouble(v, e.ay, e.by, e.ax, e.bx),
    );
    final uEnd = ((e.ax > e.bx) != (e.ay > e.by)) ^ vEnd;
    return _updateBound(edge, uEnd, u, vEnd, v);
  }

  _ClippedEdge _updateBound(
    _ClippedEdge edge,
    bool uEnd,
    double u,
    bool vEnd,
    double v,
  ) {
    final newBound = R2Rect(
      uEnd
          ? R1Interval(edge.bound.x.lo, u)
          : R1Interval(u, edge.bound.x.hi),
      vEnd
          ? R1Interval(edge.bound.y.lo, v)
          : R1Interval(v, edge.bound.y.hi),
    );
    return _ClippedEdge.withBound(edge.orig, newBound);
  }

  void _clipVAxis(
    _ClippedEdge edge,
    R1Interval middle,
    List<_ClippedEdge> edges0,
    List<_ClippedEdge> edges1,
  ) {
    if (edge.bound.y.hi <= middle.lo) {
      edges0.add(edge);
    } else if (edge.bound.y.lo >= middle.hi) {
      edges1.add(edge);
    } else {
      edges0.add(_clipVBound(edge, true, middle.hi));
      edges1.add(_clipVBound(edge, false, middle.lo));
    }
  }
}

/// Temporary edge data during index construction.
class _FaceEdge {
  final int shapeId;
  final int edgeId;
  final int maxLevel;
  final double ax, ay, bx, by;
  final S2Point va, vb;

  _FaceEdge(
    this.shapeId,
    this.edgeId,
    this.va,
    this.vb,
    this.ax,
    this.ay,
    this.bx,
    this.by,
    double cellSizeToLongEdgeRatio,
  ) : maxLevel = _getEdgeMaxLevel(va, vb, cellSizeToLongEdgeRatio);

  static int _getEdgeMaxLevel(S2Point va, S2Point vb, double ratio) {
    final maxCellEdge = va.getDistance(vb) * ratio;
    return S2Projections.avgEdge.getMinLevel(maxCellEdge);
  }
}

/// Portion of a FaceEdge clipped to an S2Cell.
class _ClippedEdge {
  final _FaceEdge orig;
  final R2Rect bound;

  _ClippedEdge(this.orig)
      : bound = R2Rect(
          R1Interval.fromPointPair(orig.ax, orig.bx),
          R1Interval.fromPointPair(orig.ay, orig.by),
        );

  _ClippedEdge.withBound(this.orig, this.bound);
}

/// Tracks which shapes contain the current focus point.
class _InteriorTracker {
  bool _isActive = false;
  S2Point _focus = S2.origin;
  S2CellId _nextCellId = S2CellId.begin(S2CellId.maxLevel);
  final EdgeCrosser _crosser = EdgeCrosser();
  List<int> _focusedShapes = List.filled(8, 0);
  int focusCount = 0;

  _InteriorTracker() {
    // Draw from focus (origin) to entry vertex of first cell
    drawTo(S2Projections.faceUvToXyz(0, -1, -1).normalize());
  }

  bool get isActive => _isActive;

  void ensureSize(int numShapes) {
    if (numShapes > _focusedShapes.length) {
      _focusedShapes = List.filled(numShapes, 0);
    }
    _isActive = false;
    focusCount = 0;
  }

  void addShape(int shapeId, S2Shape shape) {
    _isActive = true;
    if (shape.containsOrigin) {
      toggleShape(shapeId);
    }
  }

  void moveTo(S2Point b) {
    _focus = b;
  }

  void drawTo(S2Point focus) {
    _crosser.init(_focus, focus);
    _focus = focus;
  }

  void testEdge(int shapeId, S2Point start, S2Point end) {
    if (_crosser.edgeOrVertexCrossing(start, end)) {
      toggleShape(shapeId);
    }
  }

  void doneCellId(S2CellId cellId) {
    _nextCellId = cellId.rangeMax.next;
  }

  bool atCellId(S2CellId cellId) {
    return cellId.rangeMin.id == _nextCellId.id;
  }

  void toggleShape(int shapeId) {
    if (focusCount == 0) {
      _focusedShapes[0] = shapeId;
      focusCount++;
    } else if (_focusedShapes[0] == shapeId) {
      if (--focusCount > 0) {
        _focusedShapes.setRange(0, focusCount, _focusedShapes.sublist(1));
      }
    } else {
      int pos = 0;
      while (_focusedShapes[pos] < shapeId) {
        if (++pos == focusCount) {
          _focusedShapes[focusCount++] = shapeId;
          return;
        }
      }
      if (_focusedShapes[pos] == shapeId) {
        focusCount--;
        _focusedShapes.setRange(pos, focusCount, _focusedShapes.sublist(pos + 1));
      } else {
        for (int i = focusCount; i > pos; i--) {
          _focusedShapes[i] = _focusedShapes[i - 1];
        }
        _focusedShapes[pos] = shapeId;
        focusCount++;
      }
    }
  }
}

/// State for an active index build.
class _IndexState {
  final S2ShapeIndexOptions options;
  final _InteriorTracker tracker = _InteriorTracker();
  final List<S2Shape?> shapes;
  final List<S2ShapeIndexCell> cells = [];

  _IndexState(this.options, this.shapes) {
    tracker.ensureSize(shapes.length);
  }
}
