// Copyright 2016 Google Inc.
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
// Ported from com.google.common.geometry.S2PointCompression.java

import 'dart:math' as math;
import 'dart:typed_data';

import 'encoded_ints.dart';
import 'little_endian_input.dart';
import 'little_endian_output.dart';
import 's2_cell_id.dart';
import 's2_point.dart';
import 's2_projections.dart';

/// Given a sequence of S2Points assumed to be the center of level-k cells,
/// compresses it into a stream using the following method:
///
/// - decompose the points into (face, si, ti) tuples
/// - run-length encode the faces, combining face number and count into a varint32
/// - right shift the (si, ti) to remove the part that's constant for all cells
///   of level-k. The result is called the (pi, qi) space.
/// - 2nd derivative encode the pi and qi sequences (linear prediction)
/// - zig-zag encode all derivative values but the first, which cannot be negative
/// - interleave the zig-zag encoded values
/// - encode the first interleaved value in a fixed length encoding
/// - encode the remaining interleaved values as varint64s
///
/// In addition, provides a lossless method to compress a sequence of points
/// even if some points are not the center of level-k cells.
class S2PointCompression {
  S2PointCompression._();

  static const int _derivativeEncodingOrder = 2;

  /// Encode a list of points into an efficient, lossless binary representation.
  ///
  /// Points that are snapped to the specified level will require approximately
  /// 4 bytes per point, while other points will require 24 bytes per point.
  static Uint8List encodePointsCompressed(List<S2Point> points, int level) {
    final encoder = LittleEndianOutput();
    encodePointsCompressedTo(points, level, encoder);
    return encoder.toBytes();
  }

  /// Encode points to the given encoder.
  static void encodePointsCompressedTo(
      List<S2Point> points, int level, LittleEndianOutput encoder) {
    // Convert the points to (face, pi, qi) coordinates.
    final faces = _FaceRunCoder();
    final verticesPi = List<int>.filled(points.length, 0);
    final verticesQi = List<int>.filled(points.length, 0);
    final offCenter = <int>[];

    for (var i = 0; i < points.length; i++) {
      final faceSiTi = S2Projections.xyzToFaceSiTi(points[i]);
      faces.addFace(faceSiTi.face);
      verticesPi[i] = _siTiToPiQi(faceSiTi.si, level);
      verticesQi[i] = _siTiToPiQi(faceSiTi.ti, level);
      if (S2Projections.levelIfCenter(faceSiTi, points[i]) != level) {
        offCenter.add(i);
      }
    }

    // Encode the runs of the faces.
    faces.encode(encoder);

    // Encode the (pi, qi) coordinates of all the points, in order.
    final piCoder = NthDerivativeCoder(_derivativeEncodingOrder);
    final qiCoder = NthDerivativeCoder(_derivativeEncodingOrder);

    for (var i = 0; i < verticesPi.length; i++) {
      final pi = piCoder.encode(verticesPi[i]);
      final qi = qiCoder.encode(verticesQi[i]);

      if (i == 0) {
        // The first point will be just the (pi, qi) coordinates. NthDerivativeCoder
        // will not save anything in that case, so we encode in fixed format rather
        // than varint to avoid the varint overhead.
        final interleavedPiQi = EncodedInts.interleaveBits(pi, qi);

        // Write as little-endian bytes, truncated to the required length.
        final bytesRequired = (level + 7) ~/ 8 * 2;
        final bytes = Uint8List(bytesRequired);
        for (var j = 0; j < bytesRequired; j++) {
          bytes[j] = (interleavedPiQi >> (j * 8)) & 0xFF;
        }
        encoder.writeBytes(bytes);
      } else {
        // ZigZagEncode, as varint requires the maximum number of bytes for negative numbers.
        final zigZagEncodedPi = EncodedInts.encodeZigZag32(pi);
        final zigZagEncodedQi = EncodedInts.encodeZigZag32(qi);

        // Interleave to reduce overhead from two partial bytes to one.
        final interleavedPiQi =
            EncodedInts.interleaveBits(zigZagEncodedPi, zigZagEncodedQi);
        encoder.writeVarint64(interleavedPiQi);
      }
    }

    // Encode the number of off-center points.
    encoder.writeVarint32(offCenter.length);

    // Encode the actual off-center points.
    for (final index in offCenter) {
      encoder.writeVarint32(index);
      encoder.writeDouble(points[index].x);
      encoder.writeDouble(points[index].y);
      encoder.writeDouble(points[index].z);
    }
  }

  /// Decode a list of points that were encoded using [encodePointsCompressed].
  static List<S2Point> decodePointsCompressed(
      int numVertices, int level, Uint8List encoded) {
    final decoder = LittleEndianInput(encoded);
    return decodePointsCompressedFrom(numVertices, level, decoder);
  }

  /// Decode points from the given decoder.
  static List<S2Point> decodePointsCompressedFrom(
      int numVertices, int level, LittleEndianInput decoder) {
    final vertices = <S2Point>[];
    if (level > S2CellId.maxLevel || level < 0) {
      throw ArgumentError('Invalid S2Cell level provided: $level');
    }

    final faces = _FaceRunCoder();
    faces.decode(numVertices, decoder);
    final faceIterator = faces.getFaceIterator();

    final piCoder = NthDerivativeCoder(_derivativeEncodingOrder);
    final qiCoder = NthDerivativeCoder(_derivativeEncodingOrder);

    for (var i = 0; i < numVertices; i++) {
      int pi;
      int qi;

      if (i == 0) {
        // Read fixed-length bytes and reconstruct the interleaved coordinates.
        final bytesRequired = (level + 7) ~/ 8 * 2;
        final littleEndianBytes = decoder.readBytes(bytesRequired);
        var interleavedPiQi = 0;
        for (var j = 0; j < bytesRequired; j++) {
          interleavedPiQi |= (littleEndianBytes[j] & 0xFF) << (j * 8);
        }
        pi = piCoder.decode(EncodedInts.deinterleaveBits1(interleavedPiQi));
        qi = qiCoder.decode(EncodedInts.deinterleaveBits2(interleavedPiQi));
      } else {
        final piqi = decoder.readVarint64();
        pi = piCoder
            .decode(EncodedInts.decodeZigZag32(EncodedInts.deinterleaveBits1(piqi)));
        qi = qiCoder
            .decode(EncodedInts.decodeZigZag32(EncodedInts.deinterleaveBits2(piqi)));
      }
      final face = faceIterator.moveNext() ? faceIterator.current : 0;
      vertices.add(_facePiQiToXyz(face, pi, qi, level));
    }

    // Now decode the off-center points.
    final numOffCenter = decoder.readVarint32();
    if (numOffCenter > numVertices) {
      throw FormatException(
          'Number of off-center points is greater than total amount of points.');
    }
    for (var i = 0; i < numOffCenter; i++) {
      final index = decoder.readVarint32();
      final x = decoder.readDouble();
      final y = decoder.readDouble();
      final z = decoder.readDouble();
      if (index >= vertices.length) {
        throw FormatException('Insufficient or invalid data: index $index');
      }
      vertices[index] = S2Point(x, y, z);
    }

    return vertices;
  }

  static int _siTiToPiQi(int si, int level) {
    final siClamped = math.min(si, S2Projections.maxSiTi - 1);
    return siClamped >>> (S2CellId.maxLevel + 1 - level);
  }

  static double _piQiToST(int pi, int level) {
    // We want to recover the position at the center of the cell. If the point
    // was snapped to the center of the cell, then modf(s * 2^level) == 0.5.
    // Inverting STtoPiQi gives: s = (pi + 0.5) / 2^level.
    return (pi + 0.5) / (1 << level);
  }

  static S2Point _facePiQiToXyz(int face, int pi, int qi, int level) {
    return S2Projections.faceUvToXyz(
            face,
            S2Projections.stToUV(_piQiToST(pi, level)),
            S2Projections.stToUV(_piQiToST(qi, level)))
        .normalize();
  }
}

class _FaceRun {
  _FaceRun(this.face, this.count);
  final int face;
  int count;
}

class _FaceRunCoder {
  final List<_FaceRun> _faces = [];

  void addFace(int face) {
    if (_faces.isNotEmpty && _faces.last.face == face) {
      _faces.last.count += 1;
    } else {
      _faces.add(_FaceRun(face, 1));
    }
  }

  /// Writes the list of FaceRuns to the encoder.
  void encode(LittleEndianOutput encoder) {
    for (final run in _faces) {
      // It isn't necessary to encode the number of faces left for the last run,
      // but since this would only help if there were more than 21 faces, it will
      // be a small overall savings, much smaller than the bound encoding.
      encoder.writeVarint64(S2CellId.numFaces * run.count + run.face);
    }
  }

  /// Reads 'vertices' FaceRuns from the decoder.
  void decode(int vertices, LittleEndianInput decoder) {
    var facesParsed = 0;
    while (facesParsed < vertices) {
      final faceAndCount = decoder.readVarint64();
      final face = faceAndCount % S2CellId.numFaces;
      final count = faceAndCount ~/ S2CellId.numFaces;
      if (faceAndCount < 0) {
        throw FormatException(
            'Invalid face: $face, from faceAndCount: $faceAndCount');
      }
      if (count < 0) {
        throw FormatException(
            'Invalid count: $count, from faceAndCount: $faceAndCount');
      }
      final run = _FaceRun(face, count);
      _faces.add(run);
      facesParsed += run.count;
    }
  }

  Iterator<int> getFaceIterator() {
    return _FaceIterator(_faces);
  }
}

class _FaceIterator implements Iterator<int> {
  _FaceIterator(this._faces);
  final List<_FaceRun> _faces;
  int _runIndex = -1;
  int _usedCount = 0;
  int _current = 0;

  @override
  int get current => _current;

  @override
  bool moveNext() {
    if (_runIndex < 0 || _usedCount >= _faces[_runIndex].count) {
      _runIndex++;
      if (_runIndex >= _faces.length) {
        return false;
      }
      _usedCount = 1;
      _current = _faces[_runIndex].face;
    } else {
      _usedCount++;
      _current = _faces[_runIndex].face;
    }
    return true;
  }
}

/// Encodes/decodes a sequence of integers using Nth-order derivative encoding.
class NthDerivativeCoder {
  /// The minimum supported order.
  static const int nMin = 0;

  /// The maximum supported order.
  static const int nMax = 10;

  final int _n;
  int _m = 0;
  final List<int> _memory;

  /// Creates a coder with the given derivative order.
  NthDerivativeCoder(this._n)
      : assert(_n >= nMin && _n <= nMax, 'Unsupported N: $_n'),
        _memory = List<int>.filled(nMax, 0);

  /// Returns the derivative order of this coder.
  int get n => _n;

  /// Encodes a value and returns the encoded value.
  int encode(int k) {
    for (var i = 0; i < _m; i++) {
      final delta = k - _memory[i];
      _memory[i] = k;
      k = delta;
    }
    if (_m < _n) {
      _memory[_m] = k;
      _m++;
    }
    return k;
  }

  /// Decodes a value and returns the decoded value.
  int decode(int k) {
    if (_m < _n) {
      _m++;
    }
    for (var i = _m - 1; i >= 0; i--) {
      _memory[i] += k;
      k = _memory[i];
    }
    return k;
  }

  /// Resets the coder to its initial state.
  void reset() {
    for (var i = 0; i < _n; i++) {
      _memory[i] = 0;
    }
    _m = 0;
  }
}

