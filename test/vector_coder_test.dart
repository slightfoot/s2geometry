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

/// Tests for VectorCoder.
void main() {
  group('VectorCoder', () {
    test('testDecodeFromByteString', () {
      final expected = ['fuji', 'mutsu'];

      final b = _hexDecode('00000010040966756A696D75747375');
      final data = Bytes.fromByteArray(b);
      final offset = 3;
      final v = VectorCoder.STRING.decode(data, data.cursor(offset));
      expect(v.toList(), equals(expected));
    });

    test('testEmpty', () {
      _checkEncodedStringVector([], 1);
    });

    test('testEmptyString', () {
      _checkEncodedStringVector([''], 2);
    });

    test('testRepeatedEmptyStrings', () {
      _checkEncodedStringVector(['', '', ''], 4);
    });

    test('testOneString', () {
      _checkEncodedStringVector(['apples'], 8);
    });

    test('testTwoStrings', () {
      _checkEncodedStringVector(['fuji', 'mustu'], 12);
    });

    test('testTwoBigStrings', () {
      _checkEncodedStringVector(['x' * 10000, 'y' * 100000], 110007);
    });

    test('testByteArray', () {
      final input = <List<int>>[
        [1, 2, 3],
        [4, 5],
        []
      ];
      final encoded = VectorCoder.BYTE_ARRAY.encode(input);
      final data = Bytes.fromByteArray(encoded);
      final cursor = data.cursor();
      final actual = VectorCoder.BYTE_ARRAY.decode(data, cursor);

      expect(actual.length, equals(3));
      expect(actual[0], equals([1, 2, 3]));
      expect(actual[1], equals([4, 5]));
      expect(actual[2], equals([]));
    });

    test('testEncodedListSize', () {
      final input = ['hello', 'world', '!'];
      final encoded = VectorCoder.STRING.encode(input);
      final data = Bytes.fromByteArray(encoded);
      final cursor = data.cursor();
      final actual = VectorCoder.STRING.decode(data, cursor);

      expect(actual.encodedSize(0), equals(5)); // "hello"
      expect(actual.encodedSize(1), equals(5)); // "world"
      expect(actual.encodedSize(2), equals(1)); // "!"
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

void _checkEncodedStringVector(List<String> input, int expectedBytes) {
  final encoded = VectorCoder.STRING.encode(input);
  expect(encoded.length, equals(expectedBytes));

  final data = Bytes.fromByteArray(encoded);
  final cursor = data.cursor();
  final actual = VectorCoder.STRING.decode(data, cursor);
  expect(actual.toList(), equals(input));
  expect(cursor.position, equals(expectedBytes));
}

