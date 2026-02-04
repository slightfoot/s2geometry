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

/// Tests for UintVectorCoder.
void main() {
  group('UintVectorCoder', () {
    List<int> decodeLongsFromBytes(Bytes data, int offset) {
      final cursor = data.cursor(offset);
      final longs = UintVectorCoder.UINT64.decode(data, cursor);
      final actual = <int>[];
      for (int i = 0; i < longs.length; i++) {
        actual.add(longs.get(i));
      }
      return actual;
    }

    test('testDecodeLongsFromByteString', () {
      final expected = [0, 0, 0];

      // The first 3 bytes of 'bytes' are padding placed to ensure we are handling offsets correctly.
      final bytes = _hexDecode('00000018000000');
      final actual = decodeLongsFromBytes(Bytes.fromByteArray(bytes), 3);

      expect(actual, equals(expected));
    });

    test('testEmpty_uint64', () {
      final expected = <int>[];

      final data = _encodeUint64Vector(expected);
      final actual = _decodeUint64Vector(data);

      expect(data.length, equals(1));
      expect(actual, equals(expected));
    });

    test('testEmpty_uint32', () {
      final expected = <int>[];

      final data = _encodeUint32Vector(expected);
      final actual = _decodeUint32Vector(data);

      expect(data.length, equals(1));
      expect(actual, equals(expected));
    });

    test('testZero_uint64', () {
      final expected = [0];

      final data = _encodeUint64Vector(expected);
      final actual = _decodeUint64Vector(data);

      expect(data.length, equals(2));
      expect(actual, equals(expected));
    });

    test('testZero_uint32', () {
      final expected = [0];

      final data = _encodeUint32Vector(expected);
      final actual = _decodeUint32Vector(data);

      expect(data.length, equals(2));
      expect(actual, equals(expected));
    });

    test('testRepeatedZeros_uint64', () {
      final expected = [0, 0, 0];

      final data = _encodeUint64Vector(expected);
      expect(data.length, equals(4));

      final actual = _decodeUint64Vector(data);
      expect(actual, equals(expected));
    });

    test('testRepeatedZeros_uint32', () {
      final expected = [0, 0, 0];

      final data = _encodeUint32Vector(expected);
      final actual = _decodeUint32Vector(data);

      expect(data.length, equals(4));
      expect(actual, equals(expected));
    });

    test('testMaxInt_uint64', () {
      // ~0 in Dart is -1 (all bits set)
      final expected = [-1];  // Same as ~0L in Java for 64-bit

      final data = _encodeUint64Vector(expected);
      final actual = _decodeUint64Vector(data);

      expect(data.length, equals(9));
      expect(actual, equals(expected));
    });

    test('testMaxInt_uint32', () {
      // 0xFFFFFFFF as unsigned, stored in int
      final expected = [0xFFFFFFFF];

      final data = _encodeUint32Vector(expected);
      final actual = _decodeUint32Vector(data);

      expect(data.length, equals(5));
      expect(actual, equals(expected));
    });

    test('testOneByte_uint64', () {
      final expected = [0, 255, 1, 254];

      final data = _encodeUint64Vector(expected);
      final actual = _decodeUint64Vector(data);

      expect(data.length, equals(5));
      expect(actual, equals(expected));
    });

    test('testOneByte_uint32', () {
      final expected = [0, 255, 1, 254];

      final data = _encodeUint32Vector(expected);
      final actual = _decodeUint32Vector(data);

      expect(data.length, equals(5));
      expect(actual, equals(expected));
    });

    test('testTwoBytes_uint64', () {
      final expected = [0, 255, 256, 254];

      final data = _encodeUint64Vector(expected);
      final actual = _decodeUint64Vector(data);

      expect(data.length, equals(9));
      expect(actual, equals(expected));
    });

    test('testTwoBytes_uint32', () {
      final expected = [0, 255, 256, 254];

      final data = _encodeUint32Vector(expected);
      final actual = _decodeUint32Vector(data);

      expect(data.length, equals(9));
      expect(actual, equals(expected));
    });

    test('testThreeBytes_uint64', () {
      final expected = [0xffffff, 0x0102, 0, 0x050403];

      final data = _encodeUint64Vector(expected);
      final actual = _decodeUint64Vector(data);

      expect(data.length, equals(13));
      expect(actual, equals(expected));
    });

    test('testThreeBytes_uint32', () {
      final expected = [0xffffff, 0x0102, 0, 0x050403];

      final data = _encodeUint32Vector(expected);
      final actual = _decodeUint32Vector(data);

      expect(data.length, equals(13));
      expect(actual, equals(expected));
    });

    test('testFourBytes_uint64', () {
      final expected = [0xffffffff, 0x7FFFFFFF];  // Integer.MAX_VALUE

      final data = _encodeUint64Vector(expected);
      final actual = _decodeUint64Vector(data);

      expect(data.length, equals(9));
      expect(actual, equals(expected));
    });

    test('testFourBytes_uint32', () {
      final expected = [0xffffffff, 0x7FFFFFFF];

      final data = _encodeUint32Vector(expected);
      final actual = _decodeUint32Vector(data);

      expect(data.length, equals(9));
      expect(actual, equals(expected));
    });

    test('testEightBytes_uint64', () {
      // ~0L, 0L, 0x0102030405060708L, Long.MAX_VALUE
      final expected = [-1, 0, 0x0102030405060708, 0x7FFFFFFFFFFFFFFF];

      final data = _encodeUint64Vector(expected);
      final actual = _decodeUint64Vector(data);

      expect(data.length, equals(33));
      expect(actual, equals(expected));
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

List<int> _encodeUint64Vector(List<int> values) {
  final longs = Longs.fromList(values);
  return UintVectorCoder.UINT64.encode(longs);
}

List<int> _decodeUint64Vector(List<int> bytes) {
  final data = Bytes.fromByteArray(bytes);
  final longs = UintVectorCoder.UINT64.decode(data, data.cursor());
  final result = <int>[];
  for (int i = 0; i < longs.length; i++) {
    result.add(longs.get(i));
  }
  return result;
}

List<int> _encodeUint32Vector(List<int> values) {
  // For uint32, we keep only the lower 32 bits
  final longs = Longs.fromList(values.map((v) => v & 0xFFFFFFFF).toList());
  return UintVectorCoder.UINT32.encode(longs);
}

List<int> _decodeUint32Vector(List<int> bytes) {
  final data = Bytes.fromByteArray(bytes);
  final longs = UintVectorCoder.UINT32.decode(data, data.cursor());
  final result = <int>[];
  for (int i = 0; i < longs.length; i++) {
    // Keep as unsigned 32-bit value
    result.add(longs.get(i) & 0xFFFFFFFF);
  }
  return result;
}

