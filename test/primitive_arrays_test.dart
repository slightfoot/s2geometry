// Copyright 2019 Google Inc.
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

import 'package:s2geometry/s2geometry.dart';
import 'package:test/test.dart';

/// Unit tests for PrimitiveArrays.
void main() {
  group('PrimitiveArrays', () {
    // Note: Java testCreateBytes uses BufferUtils.createBytes(ByteBuffer.wrap(b))
    // which is equivalent to Bytes.fromByteArray in Dart.
    test('testCreateBytes', () {
      final b = <int>[0, 1, 2];
      final data = Bytes.fromByteArray(b);

      expect(data.length, equals(3));
      for (int i = 0; i < b.length; i++) {
        expect(data.get(i), equals(b[i]));
      }
    });

    test('testBytesFromByteArray', () {
      final b = <int>[0, 1, 2];
      final data = Bytes.fromByteArray(b);

      expect(data.length, equals(3));
      for (int i = 0; i < b.length; i++) {
        expect(data.get(i), equals(b[i]));
      }
    });

    test('testBytesToInputStream', () {
      final b = <int>[0, 1, 2, 3, 4, 5];
      final data = Bytes.fromByteArray(b);

      // In Dart, we use toUint8List() instead of toInputStream()
      final actual = data.toUint8List();
      expect(actual.length, equals(b.length));
      expect(actual.toList(), equals(b));
    });

    test('testBytesReadVarint64', () {
      // 0b10101100, 0b00000010 encodes 300
      final b = <int>[0xAC, 0x02];
      final data = Bytes.fromByteArray(b);

      final cursor = data.cursor();
      expect(data.readVarint64(cursor), equals(300));
      expect(cursor.position, equals(2));
    });

    test('testBytesReadVarint64_malformed', () {
      // 11 bytes of 0xFF is a malformed varint
      final b = List<int>.filled(11, 0xFF);
      final data = Bytes.fromByteArray(b);

      final cursor = data.cursor();
      expect(
        () => data.readVarint64(cursor),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          equals('Malformed varint.'),
        )),
      );
    });

    test('testBytesReadUintWithLength', () {
      // 0xFFFF = 65535
      final b = <int>[0xFF, 0xFF];
      final data = Bytes.fromByteArray(b);

      final cursor = data.cursor();
      expect(data.readUintWithLength(cursor, b.length), equals(65535));
      expect(cursor.position, equals(b.length));
    });

    test('testBytesReadLittleEndianDouble', () {
      // Little-endian encoding of 123.0 as IEEE754 double
      final b = <int>[0, 0, 0, 0, 0, 0xC0, 0x5E, 0x40];
      final data = Bytes.fromByteArray(b);

      expect(data.readLittleEndianDouble(0), equals(123.0));
    });

    test('testLongsFromList', () {
      final expected = <int>[1, 2, 3];
      final actual = Longs.fromList(expected);

      expect(actual.length, equals(expected.length));
      for (int i = 0; i < actual.length; i++) {
        expect(actual.get(i), equals(expected[i]));
      }
    });

    test('testLongsToIntArray', () {
      final actual = Longs.fromList([1, 2, 3]);
      final expected = actual.toIntArray();

      expect(expected.length, equals(actual.length));
      for (int i = 0; i < actual.length; i++) {
        expect(expected[i], equals(actual.get(i)));
      }

      // Test overflow case - value larger than int32 max
      expect(
        () => Longs.fromList([0x7FFFFFFFFFFFFFFF]).toIntArray(),
        throwsA(isA<ArgumentError>()),
      );
    });

    // Additional tests for Cursor
    test('testCursor', () {
      final data = Bytes.fromByteArray([1, 2, 3, 4, 5]);
      final cursor = data.cursor(1, 4);

      expect(cursor.position, equals(1));
      expect(cursor.limit, equals(4));
      expect(cursor.remaining, equals(3));

      cursor.seek(2);
      expect(cursor.position, equals(2));
      expect(cursor.remaining, equals(2));
    });

    test('testBytesIsEqualTo', () {
      final a = Bytes.fromByteArray([1, 2, 3]);
      final b = Bytes.fromByteArray([1, 2, 3]);
      final c = Bytes.fromByteArray([1, 2, 4]);
      final d = Bytes.fromByteArray([1, 2]);

      expect(a.isEqualTo(b), isTrue);
      expect(a.isEqualTo(c), isFalse);
      expect(a.isEqualTo(d), isFalse);
      expect(a.isEqualTo(null), isFalse);
    });
  });
}

