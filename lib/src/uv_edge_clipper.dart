// Copyright 2024 Google Inc.
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

import 'r2_edge.dart';
import 'r2_edge_clipper.dart';
import 'r2_rect.dart';
import 's2_cell.dart';
import 's2_edge_util.dart';
import 's2_point.dart';
import 's2_projections.dart';

/// A clipper of shape edges to rectangular regions in UV space.
///
/// Layered over [R2EdgeClipper], providing UV specific semantics and error
/// bounds. UVEdgeClipper isn't cell specific. It can clip to any rectangular
/// region in UV space, set via calling [init] or the equivalent constructor
/// before clipping edges.
///
/// Since clipping to [S2Cell] boundaries is the most common use of this class,
/// we provide a convenience method [initFromCell] and equivalent constructor
/// which set the face and clip rect from the cell.
///
/// UVEdgeClipper does not clip exactly or use exact tests to determine
/// boundary crossings, so it is possible for points very close to the boundary
/// to falsely test as crossing. We include an error bound when reporting UV
/// edges so that care can be taken in those cases.
///
/// We use the Cohen-Sutherland algorithm which classifies each endpoint of an
/// edge by which region it falls into relative to the clip region: top, bottom,
/// left and right.
class UVEdgeClipper {
  final R2EdgeClipper _r2Clipper = R2EdgeClipper();

  /// The face being clipped to.
  int _clipFace = 0;

  /// Face of the last vertex.
  int _lastFace = 0;

  final R2Edge _faceUvEdge = R2Edge();
  double _uvError = 0;
  bool _missedFace = false;

  /// Constructor that does not set a face or region.
  UVEdgeClipper();

  /// Constructor that sets the face and clip region to the given values.
  UVEdgeClipper.fromFaceAndRegion(int face, R2Rect region) {
    init(face, region);
  }

  /// Constructor that sets the face and clip region to the boundary of the
  /// given cell.
  UVEdgeClipper.fromCell(S2Cell cell) {
    initFromCell(cell);
  }

  /// Initialize the clipper to clip to the given UV region on the given face.
  void init(int face, R2Rect region) {
    _clipFace = face;
    _r2Clipper.init(region);
  }

  /// Initialize the clipper to clip to the given S2Cell.
  void initFromCell(S2Cell cell) {
    init(cell.face, cell.boundUV);
  }

  /// Returns the face being clipped to.
  int get clipFace => _clipFace;

  /// Returns the current clipping rectangle.
  R2Rect get clipRect => _r2Clipper.clipRect;

  /// Clip an edge to the current face and clip region.
  ///
  /// After clipping, result details can be obtained by calling [missedFace],
  /// [uvError], [clipError], [faceUvEdge], [clippedUvEdge], and [outcode]
  /// as needed.
  ///
  /// If the edge intersects both the face and clip region, returns true,
  /// false otherwise. If the edge misses the clip region, then it may have
  /// missed either because it missed the face entirely or hit the face but
  /// missed the clip region. The [missedFace] method can be used to
  /// distinguish between the two cases.
  ///
  /// If [connected] is true, then the clipper assumes the current edge follows
  /// the previous edge passed to clipEdge() (i.e. current.v0 == previous.v1)
  /// and will reuse previous computations.
  bool clipEdge(S2Point v0, S2Point v1, {bool connected = false}) {
    // Check that we didn't get the origin somehow, since we use it as a
    // sentinel value, and that none of the points are larger than we
    // allowed for in our error bounds.
    assert(!v0.equalsPoint(S2Point.zero) && !v1.equalsPoint(S2Point.zero));
    assert(v0.largestAbsComponent <= 2);
    assert(v1.largestAbsComponent <= 2);

    // We'll convert to UV directly into the faceUvEdge field.
    int face0;
    int face1;

    bool needFaceClip = false;
    if (connected) {
      face0 = _lastFace;
      face1 = S2Projections.xyzToFace(v1);
      if (face0 != face1 || face0 != _clipFace) {
        // Vertices are on different faces, or the same face, but not this face.
        needFaceClip = true;
      } else {
        // Vertices are both on the clip face, just convert v1.
        _faceUvEdge.v0.setFrom(_faceUvEdge.v1);
        S2Projections.validFaceXyzToUvInto(face1, v1, _faceUvEdge.v1);
      }
    } else {
      // We can't re-use the values from the last vertex for whatever reason,
      // so just convert and clip both vertices.
      face0 = S2Projections.xyzToFace(v0);
      face1 = S2Projections.xyzToFace(v1);
      if (face0 != face1 || face0 != _clipFace) {
        // Vertices are on different faces, or the same face, but not this face.
        needFaceClip = true;
      } else {
        // Both vertices are on the clip face, convert both to UV directly.
        S2Projections.validFaceXyzToUvInto(face0, v0, _faceUvEdge.v0);
        S2Projections.validFaceXyzToUvInto(face0, v1, _faceUvEdge.v1);
      }
    }
    _lastFace = face1;

    // The vertices are on different faces, clip the edge to the clip face.
    _missedFace = false;
    if (needFaceClip) {
      if (!S2EdgeUtil.clipToPaddedFace(v0, v1, _clipFace,
          S2EdgeUtil.FACE_CLIP_ERROR_UV_COORD, _faceUvEdge.v0, _faceUvEdge.v1)) {
        _missedFace = true;
        return false;
      }
    }

    // Set error bounds for converting vertices to the face.
    _uvError = S2Projections.maxXyzToUvError;
    if (needFaceClip) {
      _uvError += S2EdgeUtil.FACE_CLIP_ERROR_UV_COORD;
    }

    // Clip the edge as though it's a regular R2 edge.
    return _r2Clipper.clipEdge(_faceUvEdge, connected);
  }

  /// When the edge misses the clip region, this indicates whether it was
  /// because the edge missed the face entirely or not.
  bool get missedFace => _missedFace;

  /// Returns the maximum absolute error incurred from converting the edge to
  /// UV coordinates and clipping to the clip face. This is the error bound in
  /// each UV coordinate of the vertices of faceUvEdge().
  ///
  /// When both vertices are on the clip face, we only have to convert from XYZ
  /// to UV coordinates, which is very accurate (DBL_EPSILON/4 absolute error).
  ///
  /// If we have to clip the edge to the clip face too, more error is incurred,
  /// (FACE_CLIP_ERROR_UV_COORD), which is added to the error bound.
  double get uvError => _uvError;

  /// Returns the maximum absolute error incurred computing an intersection
  /// point on the boundary of the clip region.
  ///
  /// When an edge crosses the clip region and we have to compute new vertices
  /// for it, this is the error bound for each of the UV coordinates of the
  /// resulting vertex.
  ///
  /// This necessarily includes uvError() and any additional error incurred
  /// from linearly interpolating the vertex onto the boundary. We may end up
  /// clipping an edge twice and we can have uv conversion error on both
  /// vertices, so we multiply by two.
  double get clipError => 2 * (_uvError + R2EdgeClipper.maxUnitClipError);

  /// If the edge intersected the clip face, returns the full UV edge after it
  /// has been clipped to the face but before it has been clipped to the clip
  /// region.
  R2Edge get faceUvEdge => _faceUvEdge;

  /// If the edge intersected the clip region, returns the clipped edge.
  R2Edge get clippedUvEdge => _r2Clipper.clippedEdge;

  /// Returns the final outcode computed for a vertex.
  ///
  /// This value indicates which edge of the clip region the vertex landed on.
  /// If the vertex was inside the clip region to begin with, it's not modified
  /// so this returns [R2EdgeClipper.inside].
  ///
  /// If [missedFace] is true or [clipEdge] returned false (indicating a miss),
  /// this will return [R2EdgeClipper.outside].
  ///
  /// If a vertex manages to land exactly on a corner of the region (touching
  /// two edges), this will return one of the two edges. Which one is
  /// unspecified but will always be the same during a particular run of the
  /// program.
  ///
  /// [vertex] must be 0 or 1.
  int outcode(int vertex) {
    if (vertex == 0) {
      return _r2Clipper.outcode0;
    } else if (vertex == 1) {
      return _r2Clipper.outcode1;
    }
    throw ArgumentError('vertex must be 0 or 1');
  }
}

