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

import 'package:test/test.dart';
import 'package:s2geometry/s2geometry.dart';

/// Tests for S2CellIdVectorCoder.
void main() {
  final NONE = S2CellId.none;
  final SENTINEL = S2CellId.sentinel;

  group('S2CellIdVectorCoder', () {
    test('testDecodeFromByteString', () {
      final expected = [SENTINEL, SENTINEL];

      final bytes = Bytes.fromByteArray(_hexDecode('00000007FFFFFFFFFFFFFF10FFFF'));
      final actual = S2CellIdVectorCoder.INSTANCE.decode(bytes, bytes.cursor(3));

      expect(actual.toList(), equals(expected));
    });

    test('testEmpty', () {
      _checkEncodeDecode([], 2);
    });

    test('testNone', () {
      _checkEncodeDecode([NONE.id], 3);
    });

    test('testNoneNone', () {
      _checkEncodeDecode([NONE.id, NONE.id], 4);
    });

    test('testSentinel', () {
      _checkEncodeDecode([SENTINEL.id], 10);
    });

    test('testMaximumShiftCell', () {
      // Tests the encoding of a single cell at level 2
      _checkEncodeDecode([S2CellId.fromDebugString('0/00').id], 3);
    });

    test('testSentinelSentinel', () {
      _checkEncodeDecode([SENTINEL.id, SENTINEL.id], 11);
    });

    test('testNoneSentinelNone', () {
      _checkEncodeDecode([NONE.id, SENTINEL.id, NONE.id], 26);
    });

    test('testInvalidCells', () {
      // Tests that cells with an invalid LSB can be encoded.
      _checkEncodeDecode([0x6, 0xe, 0x7e], 5);
    });

    test('testOneByteLeafCells', () {
      _checkEncodeDecode([0x3, 0x7, 0x177], 5);
    });

    test('testOneByteLevel29Cells', () {
      _checkEncodeDecode([0xc, 0x1c, 0x47c], 5);
    });

    test('testOneByteLevel28Cells', () {
      _checkEncodeDecode([0x30, 0x70, 0x1770], 6);
    });

    test('testOneByteMixedCellLevels', () {
      _checkEncodeDecode([0x300, 0x1c00, 0x7000, 0xff00], 6);
    });

    test('testOneByteMixedCellLevelsWithPrefix', () {
      _checkEncodeDecode([
        0x1234567800000300,
        0x1234567800001c00,
        0x1234567800007000,
        0x123456780000ff00
      ], 10);
    });

    test('testOneByteRangeWithBaseValue', () {
      _checkEncodeDecode([
        0x00ffff0000000000,
        0x0100fc0000000000,
        0x0100500000000000,
        0x0100330000000000
      ], 9);
    });

    test('testSixFaceCells', () {
      final expected = <int>[];
      for (int face = 0; face < 6; face++) {
        expected.add(S2CellId.fromFace(face).id);
      }
      _checkEncodeDecode(expected, 8);
    });

    test('testFourLevel10Children', () {
      final expected = <int>[];
      final parent = S2CellId.fromDebugString('3/012301230');
      for (S2CellId id = parent.childBegin; id != parent.childEnd; id = id.next) {
        expected.add(id.id);
      }
      _checkEncodeDecode(expected, 8);
    });

    test('testShift', () {
      _checkEncodeDecode([0x1689100000000000], 5);
    });

    test('testLowerBoundLimits', () {
      final first = S2CellId.begin(S2CellId.maxLevel);
      final last = S2CellId.end(S2CellId.maxLevel).prev;

      final encoded = S2CellIdVectorCoder.INSTANCE.encode([first, last]);
      final bytes = Bytes.fromByteArray(encoded);
      final cellIds = S2CellIdVectorCoder.INSTANCE.decode(bytes, bytes.cursor());

      expect(cellIds.lowerBound(NONE), equals(0));
      expect(cellIds.lowerBound(first), equals(0));
      expect(cellIds.lowerBound(first.next), equals(1));
      expect(cellIds.lowerBound(last.prev), equals(1));
      expect(cellIds.lowerBound(last), equals(1));
      expect(cellIds.lowerBound(last.next), equals(2));
      expect(cellIds.lowerBound(SENTINEL), equals(2));
    });

    test('testEncodedS2CellIdVectorInitNeverCrashesRegression', () {
      final overflowBytes = [32, 135, 128, 128, 128, 48, 39, 132, 143, 84];
      final bytes = Bytes.fromByteArray(overflowBytes);
      expect(() => S2CellIdVectorCoder.INSTANCE.decode(bytes, bytes.cursor()),
          throwsFormatException);
    });

    test('testCoveringCells', () {
      final expected = [
        0x414a617f00000000, 0x414a61c000000000, 0x414a624000000000, 0x414a63c000000000,
        0x414a647000000000, 0x414a64c000000000, 0x414a653000000000, 0x414a704000000000,
        0x414a70c000000000, 0x414a714000000000, 0x414a71b000000000, 0x414a7a7c00000000,
        0x414a7ac000000000, 0x414a8a4000000000, 0x414a8bc000000000, 0x414a8c4000000000,
        0x414a8d7000000000, 0x414a8dc000000000, 0x414a914000000000, 0x414a91c000000000,
        0x414a924000000000, 0x414a942c00000000, 0x414a95c000000000, 0x414a96c000000000,
        0x414ab0c000000000, 0x414ab14000000000, 0x414ab34000000000, 0x414ab3c000000000,
        0x414ab44000000000, 0x414ab4c000000000, 0x414ab6c000000000, 0x414ab74000000000,
        0x414ab8c000000000, 0x414ab94000000000, 0x414aba1000000000, 0x414aba3000000000,
        0x414abbc000000000, 0x414abe4000000000, 0x414abec000000000, 0x414abf4000000000,
        0x46b5454000000000, 0x46b545c000000000, 0x46b5464000000000, 0x46b547c000000000,
        0x46b5487000000000, 0x46b548c000000000, 0x46b5494000000000, 0x46b54a5400000000,
        0x46b54ac000000000, 0x46b54b4000000000, 0x46b54bc000000000, 0x46b54c7000000000,
        0x46b54c8004000000, 0x46b54ec000000000, 0x46b55ad400000000, 0x46b55b4000000000,
        0x46b55bc000000000, 0x46b55c4000000000, 0x46b55c8100000000, 0x46b55dc000000000,
        0x46b55e4000000000, 0x46b5604000000000, 0x46b560c000000000, 0x46b561c000000000,
        0x46ca424000000000, 0x46ca42c000000000, 0x46ca43c000000000, 0x46ca444000000000,
        0x46ca45c000000000, 0x46ca467000000000, 0x46ca469000000000, 0x46ca5fc000000000,
        0x46ca604000000000, 0x46ca60c000000000, 0x46ca674000000000, 0x46ca679000000000,
        0x46ca67f000000000, 0x46ca684000000000, 0x46ca855000000000, 0x46ca8c4000000000,
        0x46ca8cc000000000, 0x46ca8e5400000000, 0x46ca8ec000000000, 0x46ca8f0100000000,
        0x46ca8fc000000000, 0x46ca900400000000, 0x46ca98c000000000, 0x46ca994000000000,
        0x46ca99c000000000, 0x46ca9a4000000000, 0x46ca9ac000000000, 0x46ca9bd500000000,
        0x46ca9e4000000000, 0x46ca9ec000000000, 0x46caf34000000000, 0x46caf4c000000000,
        0x46caf54000000000,
      ];
      _checkEncodeDecode(expected, 488);
    });
  });
}

List<int> _hexDecode(String hex) {
  final result = <int>[];
  for (int i = 0; i < hex.length; i += 2) {
    result.add(int.parse(hex.substring(i, i + 2), radix: 16));
  }
  return result;
}

void _checkEncodeDecode(List<int> expected, int expectedBytes) {
  final cellIds = expected.map((id) => S2CellId(id)).toList();
  final encoded = S2CellIdVectorCoder.INSTANCE.encode(cellIds);
  final data = Bytes.fromByteArray(encoded);
  final cursor = data.cursor();
  final actual = S2CellIdVectorCoder.INSTANCE.decode(data, cursor);

  expect(encoded.length, equals(expectedBytes));
  expect(cursor.position, equals(expectedBytes));
  expect(actual.toList(), equals(cellIds));
}

extension on S2CellIdVector {
  List<S2CellId> toS2List() {
    final result = <S2CellId>[];
    for (int i = 0; i < length; i++) {
      result.add(this[i]);
    }
    return result;
  }
}

