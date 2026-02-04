// Copyright 2005 Google Inc.
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
import 's2_edge.dart';
import 's2_latlng.dart';
import 's2_latlng_rect.dart';
import 's2_point.dart';
import 's2_polyline.dart';
import 'platform.dart';

/// S2TextFormat contains a collection of functions for converting geometry to
/// and from a human-readable format. It is mainly intended for testing and
/// debugging. Be aware that the human-readable format is *not* designed to
/// preserve the full precision of the original object, so it should not be
/// used for data storage.
class S2TextFormat {
  S2TextFormat._();

  /// Returns an S2Point corresponding to the given latitude-longitude
  /// coordinate in degrees. Example of the input format: "-20:150".
  ///
  /// Throws [ArgumentError] on unparsable input.
  static S2Point makePointOrDie(String str) {
    final point = makePoint(str);
    if (point == null) {
      throw ArgumentError('Invalid point string: "$str"');
    }
    return point;
  }

  /// As [makePointOrDie] above, but returns null if conversion is unsuccessful.
  static S2Point? makePoint(String str) {
    final vertices = parsePoints(str);
    if (vertices == null || vertices.length != 1) {
      return null;
    }
    return vertices[0];
  }

  /// Parses a string of one or more comma-separated latitude-longitude
  /// coordinates in degrees, and returns the corresponding List of S2LatLng.
  ///
  /// Examples of the input format:
  ///     ""                          // no points
  ///     "-20:150"                   // one point
  ///     "-20:150, -20:151, -19:150" // three points
  ///
  /// Throws [ArgumentError] on unparsable input.
  static List<S2LatLng> parseLatLngsOrDie(String str) {
    final latlngs = parseLatLngs(str);
    if (latlngs == null) {
      throw ArgumentError('Invalid latlngs string: "$str"');
    }
    return latlngs;
  }

  /// As [parseLatLngsOrDie] above, but returns null if conversion is
  /// unsuccessful.
  static List<S2LatLng>? parseLatLngs(String str) {
    final entries = _dictionaryParse(str);
    if (entries == null) {
      return null;
    }
    final latlngs = <S2LatLng>[];
    for (final entry in entries) {
      final lat = double.tryParse(entry.key);
      if (lat == null) {
        return null;
      }
      final lng = double.tryParse(entry.value);
      if (lng == null) {
        return null;
      }
      latlngs.add(S2LatLng.fromDegrees(lat, lng));
    }
    return latlngs;
  }

  /// Parses multiple points from a string, where the points are separated by
  /// '|', using [makePointOrDie] to parse each point.
  static List<S2Point> makePointsOrDie(String str) {
    final result = <S2Point>[];
    for (final lineStr in splitString(str, r'\|')) {
      result.add(makePointOrDie(lineStr));
    }
    return result;
  }

  /// Parses a string in the same format as [parseLatLngs], and returns the
  /// corresponding List of S2Point values.
  ///
  /// Throws [ArgumentError] on unparsable input.
  static List<S2Point> parsePointsOrDie(String str) {
    final vertices = parsePoints(str);
    if (vertices == null) {
      throw ArgumentError('Invalid points string: "$str"');
    }
    return vertices;
  }

  /// As [parsePointsOrDie] above, but returns null if conversion is
  /// unsuccessful.
  static List<S2Point>? parsePoints(String str, [int level = -1]) {
    final latlngs = parseLatLngs(str);
    if (latlngs == null) {
      return null;
    }
    final vertices = <S2Point>[];
    for (final latlng in latlngs) {
      var vertex = latlng.toPoint();
      if (level >= 0) {
        vertex = snapPointToLevel(vertex, level);
      }
      vertices.add(vertex);
    }
    return vertices;
  }

  /// Parses the given String into S2Points and appends them to the provided
  /// list of vertices. Returns the bounding rectangle of the parsed points.
  static S2LatLngRect parseVertices(String str, List<S2Point> vertices) {
    final points = parsePoints(str) ?? [];
    var rect = S2LatLngRect.empty();
    for (final point in points) {
      vertices.add(point);
      rect = rect.addPoint(S2LatLng.fromPoint(point));
    }
    return rect;
  }

  /// Snaps the given S2Point to the nearest S2CellId center at the given level.
  static S2Point snapPointToLevel(S2Point point, int level) {
    return S2CellId.fromPoint(point).parentAtLevel(level).toPoint();
  }

  /// Snaps the given list of S2Points to the nearest S2CellId centers.
  static List<S2Point> snapPointsToLevel(List<S2Point> points, int level) {
    return points.map((p) => snapPointToLevel(p, level)).toList();
  }

  /// Given a string in the same format as [parseLatLngs], returns a single
  /// S2LatLng. Throws [ArgumentError] on unparsable input.
  static S2LatLng makeLatLngOrDie(String str) {
    final latlng = makeLatLng(str);
    if (latlng == null) {
      throw ArgumentError('Invalid latlng string: "$str"');
    }
    return latlng;
  }

  /// As [makeLatLngOrDie] above, but returns null if conversion is
  /// unsuccessful.
  static S2LatLng? makeLatLng(String str) {
    final latlngs = parseLatLngs(str);
    if (latlngs == null || latlngs.length != 1) {
      return null;
    }
    return latlngs[0];
  }

  /// Parses the given String into a list of S2Edges. Edges are separated by
  /// ';' and consist of two lat/lng vertices separated by commas.
  static List<S2Edge> makeEdgesOrDie(String str) {
    final edges = <S2Edge>[];
    for (final edgeStr in splitString(str, ';')) {
      final latlngs = parsePointsOrDie(edgeStr);
      if (latlngs.length != 2) {
        throw ArgumentError('Edge string with size != 2');
      }
      edges.add(S2Edge(latlngs[0], latlngs[1]));
    }
    return edges;
  }

  /// Given a string in the same format as [parseLatLngs], returns the minimal
  /// bounding S2LatLngRect that contains the coordinates.
  ///
  /// Throws [ArgumentError] on unparsable input.
  static S2LatLngRect makeLatLngRectOrDie(String str) {
    final rect = makeLatLngRect(str);
    if (rect == null) {
      throw ArgumentError('Invalid latlngrect string: "$str"');
    }
    return rect;
  }

  /// As [makeLatLngRectOrDie] above, but returns null if conversion is
  /// unsuccessful.
  static S2LatLngRect? makeLatLngRect(String str) {
    final latlngs = parseLatLngs(str);
    if (latlngs == null || latlngs.isEmpty) {
      return null;
    }
    var rect = S2LatLngRect.fromPoint(latlngs[0]);
    for (int i = 1; i < latlngs.length; ++i) {
      rect = rect.addPoint(latlngs[i]);
    }
    return rect;
  }

  /// Parses an S2CellId in the format "f/dd..d" where "f" is a digit in the
  /// range [0-5] representing the S2CellId face, and "dd..d" is a string of
  /// digits in the range [0-3] representing each child's position with respect
  /// to its parent.
  ///
  /// Throws [ArgumentError] on unparsable input.
  static S2CellId makeCellIdOrDie(String str) {
    final cellId = makeCellId(str);
    if (cellId == null) {
      throw ArgumentError('Invalid cellid string: "$str"');
    }
    return cellId;
  }

  /// As [makeCellIdOrDie] above, but returns null if conversion is
  /// unsuccessful.
  static S2CellId? makeCellId(String str) {
    final cellId = _fromDebugString(str);
    if (cellId == S2CellId.none) {
      return null;
    }
    return cellId;
  }

  /// Parses an S2CellId in the format "f/dd..d".
  static S2CellId _fromDebugString(String str) {
    final parts = str.split('/');
    if (parts.length != 2) {
      return S2CellId.none;
    }
    final face = int.tryParse(parts[0]);
    if (face == null || face < 0 || face > 5) {
      return S2CellId.none;
    }
    var id = S2CellId.fromFace(face);
    for (int i = 0; i < parts[1].length; i++) {
      final child = int.tryParse(parts[1][i]);
      if (child == null || child < 0 || child > 3) {
        return S2CellId.none;
      }
      id = id.child(child);
    }
    return id;
  }

  /// Parses a comma-separated list of S2CellIds as described in
  /// [makeCellIdOrDie], and returns the corresponding S2CellUnion.
  ///
  /// Throws [ArgumentError] on unparsable input.
  static S2CellUnion makeCellUnionOrDie(String str) {
    final cellUnion = makeCellUnion(str);
    if (cellUnion == null) {
      throw ArgumentError('Invalid cellunion string: "$str"');
    }
    return cellUnion;
  }

  /// As [makeCellUnionOrDie] above, but returns null if conversion is
  /// unsuccessful.
  static S2CellUnion? makeCellUnion(String str) {
    final cellIds = <S2CellId>[];
    for (var cellStr in splitString(str, ',')) {
      cellStr = cellStr.trim();
      final cellId = makeCellId(cellStr);
      if (cellId == null) {
        return null;
      }
      cellIds.add(cellId);
    }
    return S2CellUnion.fromCellIds(cellIds);
  }

  /// Parses multiple polylines from a string, where the polylines are
  /// separated by '|', using [makePolylineOrDie] to parse each polyline.
  static List<S2Polyline> makePolylinesOrDie(String str) {
    final result = <S2Polyline>[];
    for (final lineStr in splitString(str, r'\|')) {
      result.add(makePolylineOrDie(lineStr));
    }
    return result;
  }

  /// Parses an input in the same format as [parseLatLngs], and returns an
  /// S2Polyline.
  ///
  /// Throws [ArgumentError] on unparsable input.
  static S2Polyline makePolylineOrDie(String str) {
    final polyline = makePolyline(str);
    if (polyline == null) {
      throw ArgumentError('Invalid polyline string: "$str"');
    }
    return polyline;
  }

  /// As [makePolylineOrDie] above, but returns null if conversion is
  /// unsuccessful.
  static S2Polyline? makePolyline(String str) {
    final vertices = parsePoints(str);
    if (vertices == null) {
      return null;
    }
    return S2Polyline(vertices);
  }

  // ======================== toString Methods ========================

  /// Convert an S2Point to the S2TextFormat string representation.
  static String pointToString(S2Point s2Point) {
    final out = StringBuffer();
    _appendVertex(s2Point, out);
    return out.toString();
  }

  /// Convert an S2LatLng to the S2TextFormat string representation.
  static String latLngToString(S2LatLng latlng) {
    final out = StringBuffer();
    _appendLatLngVertex(latlng, out);
    return out.toString();
  }

  /// Convert an S2LatLngRect to the S2TextFormat string representation.
  static String latLngRectToString(S2LatLngRect rect) {
    final out = StringBuffer();
    _appendLatLngVertex(rect.lo, out);
    out.write(', ');
    _appendLatLngVertex(rect.hi, out);
    return out.toString();
  }

  /// Convert an S2CellId to the S2TextFormat string representation.
  static String cellIdToString(S2CellId cellId) {
    return cellId.toString();
  }

  /// Convert an S2CellUnion to the S2TextFormat string representation.
  static String cellUnionToString(S2CellUnion cellUnion) {
    final out = StringBuffer();
    var first = true;
    for (final cellId in cellUnion.cellIds) {
      if (!first) {
        out.write(', ');
      }
      first = false;
      out.write(_cellIdToDebugString(cellId));
    }
    return out.toString();
  }

  /// Converts an S2CellId to the debug string format "f/dd..d".
  static String _cellIdToDebugString(S2CellId id) {
    if (!id.isValid) {
      return 'Invalid';
    }
    final face = id.face;
    final level = id.level;
    final buffer = StringBuffer('$face/');
    for (int i = 1; i <= level; i++) {
      buffer.write(id.childPositionAtLevel(i));
    }
    return buffer.toString();
  }

  /// Convert an S2Polyline to the S2TextFormat string representation.
  static String polylineToString(S2Polyline polyline) {
    final out = StringBuffer();
    _appendPolyline(polyline, out);
    return out.toString();
  }

  /// Appends an S2Polyline to StringBuffer.
  static void _appendPolyline(S2Polyline polyline, StringBuffer out) {
    if (polyline.numVertices > 0) {
      _appendVertices(polyline.vertices, out);
    }
  }

  /// Convert a list of S2Points to the S2TextFormat string representation.
  static String s2PointsToString(List<S2Point> points) {
    final out = StringBuffer();
    _appendVertices(points, out);
    return out.toString();
  }

  /// Convert a list of S2LatLngs to the S2TextFormat string representation.
  static String s2LatLngsToString(List<S2LatLng> latlngs) {
    final out = StringBuffer();
    for (int i = 0; i < latlngs.length; ++i) {
      if (i > 0) {
        out.write(', ');
      }
      _appendLatLngVertex(latlngs[i], out);
    }
    return out.toString();
  }

  /// Convert a list of S2Polylines to the S2TextFormat string representation.
  static String polylinesToString(List<S2Polyline> polylines) {
    final out = StringBuffer();
    for (int i = 0; i < polylines.length; ++i) {
      _appendPolyline(polylines[i], out);
      if (i < polylines.length - 1) {
        out.write('|\n ');
      }
    }
    return out.toString();
  }

  // ======================== Helper Methods ========================

  /// Split on the given regexp. Trim whitespace and skip empty strings.
  static List<String> splitString(String str, String regexp) {
    final parts = str.split(RegExp(regexp));
    final result = <String>[];
    for (final part in parts) {
      if (part.trim().isNotEmpty) {
        result.add(part.trim());
      }
    }
    return result;
  }

  /// Formats the given S2LatLng as a colon-separated pair of values.
  static void _appendLatLngVertex(S2LatLng ll, StringBuffer out) {
    out.write(Platform.formatDouble(ll.latDegrees));
    out.write(':');
    out.write(Platform.formatDouble(ll.lngDegrees));
  }

  /// Formats the given S2Point as an S2LatLng.
  static void _appendVertex(S2Point p, StringBuffer out) {
    _appendLatLngVertex(S2LatLng.fromPoint(p), out);
  }

  static void _appendVertices(Iterable<S2Point> points, StringBuffer out) {
    var first = true;
    for (final point in points) {
      if (!first) {
        out.write(', ');
      }
      first = false;
      _appendVertex(point, out);
    }
  }

  /// Modeled on the DictionaryParse method of strings/serialize.cc
  static List<_ParseEntry>? _dictionaryParse(String str) {
    if (str.isEmpty) {
      return [];
    }
    final items = <_ParseEntry>[];
    final entries = str.split(',');
    for (final entry in entries) {
      if (entry.trim().isEmpty) {
        continue;
      }
      final fields = entry.split(':');
      if (fields.length != 2) {
        return null;
      }
      items.add(_ParseEntry(fields[0].trim(), fields[1].trim()));
    }
    return items;
  }
}

class _ParseEntry {
  final String key;
  final String value;
  _ParseEntry(this.key, this.value);
}
