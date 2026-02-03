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

import 'dart:math' as math;

import 'r2_vector.dart';
import 's2.dart';
import 's2_cell_id.dart';
import 's2_point.dart';

/// This class specifies the coordinate systems and transforms used to project
/// points from the sphere to the unit cube to an S2CellId.
class S2Projections {
  // Cell ID constants - must match S2CellId
  static const int maxLevel = 30;
  static const int maxSize = 1 << maxLevel;

  /// The maximum value of an si- or ti-coordinate.
  static const int maxSiTi = 1 << (maxLevel + 1);

  /// Convert an s- or t-value to the corresponding u- or v-value using the
  /// quadratic projection.
  static double stToUV(double s) {
    if (s >= 0.5) {
      return (1 / 3.0) * (4 * s * s - 1);
    } else {
      return (1 / 3.0) * (1 - 4 * (1 - s) * (1 - s));
    }
  }

  /// The inverse of stToUV.
  static double uvToST(double u) {
    if (u >= 0) {
      return 0.5 * math.sqrt(1 + 3 * u);
    } else {
      return 1 - 0.5 * math.sqrt(1 - 3 * u);
    }
  }

  /// Returns the i- or j-index of the leaf cell containing the given s- or
  /// t-value.
  static int stToIj(double s) {
    return math.max(0, math.min(maxSize - 1, (maxSize * s - 0.5).round()));
  }

  /// Converts the i- or j-index of a leaf cell to the minimum corresponding
  /// s- or t-value contained by that cell.
  static double ijToStMin(int i) {
    assert(i >= 0 && i <= maxSize);
    return (1.0 / maxSize) * i;
  }

  /// Converts the specified i- or j-coordinate into its corresponding u- or
  /// v-coordinate for the given cell size.
  static double ijToUV(int ij, int cellSize) {
    return stToUV(ijToStMin(ij & -cellSize));
  }

  /// Returns the s- or t-value corresponding to the given si- or ti-value.
  static double siTiToSt(int si) {
    assert(si >= 0 && si <= maxSiTi);
    return (1.0 / maxSiTi) * si;
  }

  /// Returns the si- or ti-coordinate that is nearest to the given s- or
  /// t-value.
  static int stToSiTi(double s) {
    return (s * maxSiTi).round();
  }

  /// Convert (face, u, v) coordinates to a direction vector.
  static S2Point faceUvToXyz(int face, double u, double v) {
    switch (face) {
      case 0:
        return S2Point(1, u, v);
      case 1:
        return S2Point(-u, 1, v);
      case 2:
        return S2Point(-u, -v, 1);
      case 3:
        return S2Point(-1, -v, -u);
      case 4:
        return S2Point(v, -1, -u);
      default:
        return S2Point(v, u, -1);
    }
  }

  /// Convert (face, si, ti) coordinates to a direction vector.
  static S2Point faceSiTiToXyz(int face, int si, int ti) {
    double u = stToUV(siTiToSt(si));
    double v = stToUV(siTiToSt(ti));
    return faceUvToXyz(face, u, v);
  }

  /// Returns the face containing the given direction vector.
  static int xyzToFace(S2Point p) {
    return xyzToFaceFromCoords(p.x, p.y, p.z);
  }

  /// Returns the face containing the given coordinates.
  static int xyzToFaceFromCoords(double x, double y, double z) {
    switch (S2Point.largestAbsComponentFromCoords(x, y, z)) {
      case 0:
        return (x < 0) ? 3 : 0;
      case 1:
        return (y < 0) ? 4 : 1;
      default:
        return (z < 0) ? 5 : 2;
    }
  }

  /// Returns the U coordinate for a given face and point.
  static double xyzToU(int face, S2Point p) {
    switch (face) {
      case 0:
        return p.y / p.x;
      case 1:
        return -p.x / p.y;
      case 2:
        return -p.x / p.z;
      case 3:
        return p.z / p.x;
      case 4:
        return p.z / p.y;
      default:
        return -p.y / p.z;
    }
  }

  /// Returns the V coordinate for a given face and point.
  static double xyzToV(int face, S2Point p) {
    switch (face) {
      case 0:
        return p.z / p.x;
      case 1:
        return p.z / p.y;
      case 2:
        return -p.y / p.z;
      case 3:
        return p.y / p.x;
      case 4:
        return -p.x / p.y;
      default:
        return -p.x / p.z;
    }
  }

  /// Returns the U,V coordinates for a given face and point.
  static R2Vector validFaceXyzToUv(int face, S2Point p) {
    return R2Vector(xyzToU(face, p), xyzToV(face, p));
  }

  /// Returns the unit-length normal for the given face.
  static S2Point getNorm(int face) {
    switch (face) {
      case 0:
        return S2Point(1, 0, 0);
      case 1:
        return S2Point(0, 1, 0);
      case 2:
        return S2Point(0, 0, 1);
      case 3:
        return S2Point(-1, 0, 0);
      case 4:
        return S2Point(0, -1, 0);
      default:
        return S2Point(0, 0, -1);
    }
  }

  /// Returns the u-axis for the given face.
  static S2Point getUAxis(int face) {
    switch (face) {
      case 0:
        return S2Point(0, 1, 0);
      case 1:
        return S2Point(-1, 0, 0);
      case 2:
        return S2Point(-1, 0, 0);
      case 3:
        return S2Point(0, 0, -1);
      case 4:
        return S2Point(0, 0, -1);
      default:
        return S2Point(0, 1, 0);
    }
  }

  /// Returns the v-axis for the given face.
  static S2Point getVAxis(int face) {
    switch (face) {
      case 0:
        return S2Point(0, 0, 1);
      case 1:
        return S2Point(0, 0, 1);
      case 2:
        return S2Point(0, -1, 0);
      case 3:
        return S2Point(0, -1, 0);
      case 4:
        return S2Point(1, 0, 0);
      default:
        return S2Point(1, 0, 0);
    }
  }

  /// Returns the normal to the u-axis at the given u coordinate on the given face.
  static S2Point getUNorm(int face, double u) {
    switch (face) {
      case 0:
        return S2Point(u, -1, 0);
      case 1:
        return S2Point(1, u, 0);
      case 2:
        return S2Point(1, 0, u);
      case 3:
        return S2Point(-u, 0, 1);
      case 4:
        return S2Point(0, -u, 1);
      default:
        return S2Point(0, -1, -u);
    }
  }

  /// Returns the normal to the v-axis at the given v coordinate on the given face.
  static S2Point getVNorm(int face, double v) {
    switch (face) {
      case 0:
        return S2Point(-v, 0, 1);
      case 1:
        return S2Point(0, -v, 1);
      case 2:
        return S2Point(0, -1, -v);
      case 3:
        return S2Point(v, -1, 0);
      case 4:
        return S2Point(1, v, 0);
      default:
        return S2Point(1, 0, v);
    }
  }

  /// Returns the (u,v) coordinates for the given face and point.
  /// Returns null if the point is not on the given face.
  static R2Vector? faceXyzToUv(int face, S2Point p) {
    if (!_pointOnFace(face, p)) return null;
    return validFaceXyzToUv(face, p);
  }

  /// Returns true if the point is on the given face.
  static bool _pointOnFace(int face, S2Point p) {
    switch (face) {
      case 0:
        return p.x.abs() >= p.y.abs() && p.x.abs() >= p.z.abs() && p.x > 0;
      case 1:
        return p.y.abs() >= p.x.abs() && p.y.abs() >= p.z.abs() && p.y > 0;
      case 2:
        return p.z.abs() >= p.x.abs() && p.z.abs() >= p.y.abs() && p.z > 0;
      case 3:
        return p.x.abs() >= p.y.abs() && p.x.abs() >= p.z.abs() && p.x < 0;
      case 4:
        return p.y.abs() >= p.x.abs() && p.y.abs() >= p.z.abs() && p.y < 0;
      default:
        return p.z.abs() >= p.x.abs() && p.z.abs() >= p.y.abs() && p.z < 0;
    }
  }

  /// Average area of cells at each level.
  static final avgArea = _Metric(2, 4 * S2.pi / 6);

  /// Minimum width of cells at each level.
  static final minWidth = _Metric(1, 2 * S2.sqrt2 / 3);

  // Private constructor - this is a utility class
  S2Projections._();
}

/// A metric for cell sizes at different levels.
class _Metric {
  final int dim;
  final double deriv;

  const _Metric(this.dim, this.deriv);

  /// Returns the value of the metric at the given level.
  double getValue(int level) {
    return deriv * (1 << (-dim * level)).toDouble();
  }

  /// Returns the minimum level at which the metric is at most the given value.
  int getMinLevel(double value) {
    if (value <= 0) return S2CellId.maxLevel;

    // The minimum level is the level at which the metric is at most the given value.
    int level = 0;
    while (level < S2CellId.maxLevel && getValue(level) > value) {
      level++;
    }
    return level;
  }

  /// Returns the maximum level at which the metric is at least the given value.
  int getMaxLevel(double value) {
    if (value <= 0) return S2CellId.maxLevel;

    int level = 0;
    while (level < S2CellId.maxLevel && getValue(level + 1) >= value) {
      level++;
    }
    return level;
  }
}

