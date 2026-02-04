// Copyright 2018 Google Inc. All Rights Reserved.
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

import 'dart:convert';
import 'package:test/test.dart';
import 'package:s2geometry/s2geometry.dart';

/// Tests for S2PointVectorCoder.
void main() {
  const int blockSize = 16;

  /// Returns the number of bytes used to encode the input.
  int checkEncodeDecode(
      List<S2Point> input, S2PointVectorCoder coder, int expectedBytes) {
    final encoded = coder.encode(input);

    final data = Bytes.fromByteArray(encoded);
    final cursor = data.cursor();
    final actual = coder.decode(data, cursor);

    if (expectedBytes >= 0) {
      expect(encoded.length, equals(expectedBytes));
      expect(cursor.position, equals(expectedBytes));
    }
    expect(actual.length, equals(input.length));
    for (int i = 0; i < input.length; i++) {
      expect(actual[i].x, closeTo(input[i].x, 1e-14));
      expect(actual[i].y, closeTo(input[i].y, 1e-14));
      expect(actual[i].z, closeTo(input[i].z, 1e-14));
    }
    return encoded.length;
  }

  /// Converts an encoded 64-bit value back to an S2Point.
  S2Point encodedValueToPoint(int value, int level) {
    final sj = EncodedInts.deinterleaveBitPairs1(value);
    final tj = EncodedInts.deinterleaveBitPairs2(value);
    final shift = S2CellId.maxLevel - level;
    final si = (((sj << 1) | 1) << shift) & 0x7fffffff;
    final ti = (((tj << 1) | 1) << shift) & 0x7fffffff;
    final face = ((sj << shift) >>> 30) | (((tj << (shift + 1)) >>> 29) & 4);
    return S2Projections.faceUvToXyz(
            face,
            S2Projections.stToUV(S2Projections.siTiToSt(si)),
            S2Projections.stToUV(S2Projections.siTiToSt(ti)))
        .normalize();
  }

  group('S2PointVectorCoder', () {
    test('testEmpty', () {
      checkEncodeDecode([], S2PointVectorCoder.FAST, 1);
      // Test that an empty vector uses the FAST encoding.
      checkEncodeDecode([], S2PointVectorCoder.COMPACT, 1);
    });

    test('testOnePoint', () {
      checkEncodeDecode([S2Point(1, 0, 0)], S2PointVectorCoder.FAST, 25);
      // Encoding: header (2 bytes), block count (1 byte), block lengths (1 byte),
      // block header (1 byte), delta (1 byte).
      checkEncodeDecode([S2Point(1, 0, 0)], S2PointVectorCoder.COMPACT, 6);
    });

    test('testTenPoints', () {
      final points = <S2Point>[];
      for (int i = 0; i < 10; i++) {
        points.add(S2Point(1, i.toDouble(), 0).normalize());
      }
      checkEncodeDecode(points, S2PointVectorCoder.FAST, 241);
      checkEncodeDecode(points, S2PointVectorCoder.COMPACT, 231);
    });

    test('testCellIdWithException', () {
      // Test one point encoded as an S2CellId with one point encoded as an exception.
      checkEncodeDecode(
          [
            S2CellId.fromDebugString('1/23').toPoint(),
            S2Point(0.1, 0.2, 0.3).normalize(),
          ],
          S2PointVectorCoder.COMPACT,
          31);
    });

    test('testPointsOnDifferentFaces', () {
      checkEncodeDecode(
          [
            S2CellId(0x87f627880299f7db).toPoint(),
            S2CellId(0x52b332cd52cb8949).toPoint(),
          ],
          S2PointVectorCoder.COMPACT,
          21);
    });

    test('testNoOverlapOrExtraDeltaBitsNeeded', () {
      // From Java comments:
      // bMin = 0x72, bMax = 0x7e. The range is 0x0c. This can be encoded using
      // deltaBits = 4 and overlapBits = 0.
      final level = 3;
      final points = List.generate(blockSize, (_) => encodedValueToPoint(0, level));
      points.add(encodedValueToPoint(0x72, level));
      points.add(encodedValueToPoint(0x74, level));
      points.add(encodedValueToPoint(0x75, level));
      points.add(encodedValueToPoint(0x7e, level));
      checkEncodeDecode(points, S2PointVectorCoder.COMPACT, 10 + blockSize ~/ 2);
    });

    test('testOverlapNeeded', () {
      // bMin = 0x78, bMax = 0x84. Needs overlap to encode.
      final level = 3;
      final points = List.generate(blockSize, (_) => encodedValueToPoint(0, level));
      points.add(encodedValueToPoint(0x78, level));
      points.add(encodedValueToPoint(0x7a, level));
      points.add(encodedValueToPoint(0x7c, level));
      points.add(encodedValueToPoint(0x84, level));
      checkEncodeDecode(points, S2PointVectorCoder.COMPACT, 10 + blockSize ~/ 2);
    });

    test('testExtraDeltaBitsNeeded', () {
      // bMin = 0x08, bMax = 0x104. Needs extra delta bits.
      final level = 3;
      final points = List.generate(blockSize, (_) => encodedValueToPoint(0, level));
      points.add(encodedValueToPoint(0x08, level));
      points.add(encodedValueToPoint(0x4e, level));
      points.add(encodedValueToPoint(0x82, level));
      points.add(encodedValueToPoint(0x104, level));
      checkEncodeDecode(points, S2PointVectorCoder.COMPACT, 13 + blockSize ~/ 2);
    });

    test('testFirstAtAllLevels', () {
      for (int level = 0; level <= S2CellId.maxLevel; level++) {
        checkEncodeDecode(
            [S2CellId.begin(level).toPoint()], S2PointVectorCoder.COMPACT, 6);
      }
    });

    test('testLastAtAllLevels', () {
      for (int level = 0; level <= S2CellId.maxLevel; level++) {
        // 8 bit deltas are used for blocks of size 1, which reduces base size
        final expectedSize = 6 + level ~/ 4;
        checkEncodeDecode([S2CellId.end(level).prev.toPoint()],
            S2PointVectorCoder.COMPACT, expectedSize);
      }
    });

    test('testLastTwoPointsAtAllLevels', () {
      for (int level = 0; level <= S2CellId.maxLevel; level++) {
        final id = S2CellId.end(level).prev;
        final expectedSize = 6 + (level + 2) ~/ 4;
        checkEncodeDecode([id.toPoint(), id.prev.toPoint()],
            S2PointVectorCoder.COMPACT, expectedSize);
      }
    });

    test('testSixtyFourBitOffset', () {
      // Tests a case where a 64-bit block offset is needed.
      final level = S2CellId.maxLevel;
      final points =
          List.generate(blockSize, (_) => S2CellId.begin(level).toPoint());
      points.add(S2CellId.end(level).prev.toPoint());
      points.add(S2CellId.end(level).prev.prev.toPoint());
      checkEncodeDecode(points, S2PointVectorCoder.COMPACT, 16 + blockSize ~/ 2);
    });

    test('testAllExceptionsBlock', () {
      // Two blocks: first with 16 encodable values, second with 2 exceptions.
      final points = <S2Point>[];
      for (int i = 0; i < blockSize; i++) {
        points.add(encodedValueToPoint(0, S2CellId.maxLevel));
      }
      points.add(S2Point(0.1, 0.2, 0.3).normalize());
      points.add(S2Point(0.3, 0.2, 0.1).normalize());
      // Encoding sizes from Java comments.
      checkEncodeDecode(points, S2PointVectorCoder.COMPACT, 72);
      checkEncodeDecode(points, S2PointVectorCoder.FAST, 434);
    });

    test('testManyDuplicatePointsAtAllLevels', () {
      for (int level = 0; level <= S2CellId.maxLevel; level++) {
        final id = S2CellId.end(level).prev;
        var expectedSize = 23 + (level + 2) ~/ 4;
        if (level == 30) {
          expectedSize += 1;
        }
        final points = <S2Point>[];
        for (int i = 0; i < 32; i++) {
          points.add(id.toPoint());
        }
        checkEncodeDecode(points, S2PointVectorCoder.COMPACT, expectedSize);
      }
    });
  });
}

