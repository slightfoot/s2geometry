// Copyright 2018 Google Inc.
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

void main() {
  group('EncodedInts', () {
    test('testVarInts', () {
      final bytes = <int>[];
      // Note: Dart's int is 64-bit, but doesn't have unsigned semantics
      // so we test with values that work as signed 64-bit integers
      final values = [
        -9223372036854775808, // min int64
        -217,
        -1,
        0,
        1,
        255,
        9223372036854775807 // max int64
      ];
      
      int expectedSize = 0;
      for (final v in values) {
        expectedSize += EncodedInts.varIntSize(v);
        EncodedInts.writeVarint64(bytes, v);
      }
      expect(bytes.length, equals(expectedSize), reason: 'Expected different total size');
      
      int offset = 0;
      for (final v in values) {
        final (value, bytesRead) = EncodedInts.readVarint64(bytes, offset);
        expect(value, equals(v), reason: 'Expected different value');
        offset += bytesRead;
      }
      expect(offset, equals(bytes.length), reason: 'Expected to consume all bytes');
    });

    test('testEncodeZigZag32', () {
      expect(EncodedInts.encodeZigZag32(0), equals(0));
      expect(EncodedInts.encodeZigZag32(-1), equals(1));
      expect(EncodedInts.encodeZigZag32(1), equals(2));
      expect(EncodedInts.encodeZigZag32(-2), equals(3));
      expect(EncodedInts.encodeZigZag32(0x3FFFFFFF), equals(0x7FFFFFFE));
      expect(EncodedInts.encodeZigZag32(-1073741824), equals(0x7FFFFFFF)); // 0xC0000000 as signed
      expect(EncodedInts.encodeZigZag32(0x7FFFFFFF), equals(0xFFFFFFFE));
      expect(EncodedInts.encodeZigZag32(-2147483648), equals(0xFFFFFFFF)); // 0x80000000 as signed
    });

    test('testEncodeZigZag64', () {
      expect(EncodedInts.encodeZigZag64(0), equals(0));
      expect(EncodedInts.encodeZigZag64(-1), equals(1));
      expect(EncodedInts.encodeZigZag64(1), equals(2));
      expect(EncodedInts.encodeZigZag64(-2), equals(3));
      expect(EncodedInts.encodeZigZag64(0x000000003FFFFFFF), equals(0x000000007FFFFFFE));
      expect(EncodedInts.encodeZigZag64(-1073741824), equals(0x000000007FFFFFFF)); // 0xFFFFFFFFC0000000L
      expect(EncodedInts.encodeZigZag64(0x000000007FFFFFFF), equals(0x00000000FFFFFFFE));
      expect(EncodedInts.encodeZigZag64(-2147483648), equals(0x00000000FFFFFFFF)); // 0xFFFFFFFF80000000L
      expect(EncodedInts.encodeZigZag64(0x7FFFFFFFFFFFFFFF), equals(-2)); // 0xFFFFFFFFFFFFFFFE
      expect(EncodedInts.encodeZigZag64(-9223372036854775808), equals(-1)); // 0xFFFFFFFFFFFFFFFF

      // Round-trip tests
      expect(EncodedInts.encodeZigZag64(EncodedInts.decodeZigZag64(0)), equals(0));
      expect(EncodedInts.encodeZigZag64(EncodedInts.decodeZigZag64(1)), equals(1));
      expect(EncodedInts.encodeZigZag64(EncodedInts.decodeZigZag64(-1)), equals(-1));
      expect(EncodedInts.encodeZigZag64(EncodedInts.decodeZigZag64(14927)), equals(14927));
      expect(EncodedInts.encodeZigZag64(EncodedInts.decodeZigZag64(-3612)), equals(-3612));
      expect(EncodedInts.encodeZigZag64(EncodedInts.decodeZigZag64(856912304801416)), equals(856912304801416));
      expect(EncodedInts.encodeZigZag64(EncodedInts.decodeZigZag64(-75123905439571256)), equals(-75123905439571256));
    });

    test('testDecodeZigZag32', () {
      expect(EncodedInts.decodeZigZag32(0), equals(0));
      expect(EncodedInts.decodeZigZag32(1), equals(-1));
      expect(EncodedInts.decodeZigZag32(2), equals(1));
      expect(EncodedInts.decodeZigZag32(3), equals(-2));
      expect(EncodedInts.decodeZigZag32(0x7FFFFFFE), equals(0x3FFFFFFF));
      expect(EncodedInts.decodeZigZag32(0x7FFFFFFF), equals(-1073741824)); // 0xC0000000 as signed
      expect(EncodedInts.decodeZigZag32(0xFFFFFFFE), equals(0x7FFFFFFF));
      expect(EncodedInts.decodeZigZag32(0xFFFFFFFF), equals(-2147483648)); // 0x80000000 as signed (int32 min)
    });

    test('testDecodeZigZag64', () {
      expect(EncodedInts.decodeZigZag64(0), equals(0));
      expect(EncodedInts.decodeZigZag64(1), equals(-1));
      expect(EncodedInts.decodeZigZag64(2), equals(1));
      expect(EncodedInts.decodeZigZag64(3), equals(-2));
      expect(EncodedInts.decodeZigZag64(0x000000007FFFFFFE), equals(0x000000003FFFFFFF));
      expect(EncodedInts.decodeZigZag64(0x000000007FFFFFFF), equals(-1073741824));
      expect(EncodedInts.decodeZigZag64(0x00000000FFFFFFFE), equals(0x000000007FFFFFFF));
      expect(EncodedInts.decodeZigZag64(0x00000000FFFFFFFF), equals(-2147483648));
      expect(EncodedInts.decodeZigZag64(-2), equals(0x7FFFFFFFFFFFFFFF)); // 0xFFFFFFFFFFFFFFFE
      expect(EncodedInts.decodeZigZag64(-1), equals(-9223372036854775808)); // 0xFFFFFFFFFFFFFFFF
    });

    test('testInterleaveBits', () {
      void checkBits(int expected, int v1, int v2) {
        final bits = EncodedInts.interleaveBits(v1, v2);
        expect(bits, equals(expected));
        expect(EncodedInts.deinterleaveBits1(bits), equals(v1 & 0xFFFFFFFF));
        expect(EncodedInts.deinterleaveBits2(bits), equals(v2 & 0xFFFFFFFF));
      }

      checkBits(0xC000000000000000, 0x80000000, 0x80000000);
      checkBits(0x0000000000000000, 0x00000000, 0x00000000);
      checkBits(0x5555555555555555, 0xFFFFFFFF, 0x00000000);
      checkBits(-6148914691236517206, 0x00000000, 0xFFFFFFFF); // 0xAAAAAAAAAAAAAAAA
      checkBits(-1, 0xFFFFFFFF, 0xFFFFFFFF); // 0xFFFFFFFFFFFFFFFF
      checkBits(0x00000000000000A8, 0x00000000, 0x0000000E);
      checkBits(0x0000000000000054, 0x0000000E, 0x00000000);
    });

    test('testInterleaveBitPairs', () {
      void checkBitPairs(int expected, int v1, int v2) {
        final bits = EncodedInts.interleaveBitPairs(v1, v2);
        expect(bits, equals(expected));
        expect(EncodedInts.deinterleaveBitPairs1(bits), equals(v1 & 0xFFFFFFFF));
        expect(EncodedInts.deinterleaveBitPairs2(bits), equals(v2 & 0xFFFFFFFF));
      }

      checkBitPairs(0xA000000000000000, 0x80000000, 0x80000000);
      checkBitPairs(0x0000000000000000, 0x00000000, 0x00000000);
      checkBitPairs(0x3333333333333333, 0xFFFFFFFF, 0x00000000);
      checkBitPairs(-3689348814741910324, 0x00000000, 0xFFFFFFFF); // 0xCCCCCCCCCCCCCCCC
      checkBitPairs(-1, 0xFFFFFFFF, 0xFFFFFFFF); // 0xFFFFFFFFFFFFFFFF
      checkBitPairs(0x00000000000000C8, 0x00000000, 0x0000000E);
      checkBitPairs(0x0000000000000032, 0x0000000E, 0x00000000);
    });

    test('testUintWithLength', () {
      // Test encoding and decoding fixed-length uints
      for (int bytesPerWord = 1; bytesPerWord <= 8; bytesPerWord++) {
        final bytes = <int>[];
        final testValue = (1 << (bytesPerWord * 8 - 1)) - 1;
        EncodedInts.encodeUintWithLength(bytes, testValue, bytesPerWord);
        expect(bytes.length, equals(bytesPerWord));
        final decoded = EncodedInts.decodeUintWithLength(bytes, 0, bytesPerWord);
        expect(decoded, equals(testValue));
      }
    });

    test('testTruncatedVarint', () {
      // Test that a truncated varint throws FormatException
      // Create bytes that indicate more bytes are coming (high bit set) but then end
      final truncated = [0x80];  // High bit set means more bytes expected
      expect(
        () => EncodedInts.readVarint64(truncated, 0),
        throwsA(isA<FormatException>()),
      );
    });

    test('testMalformedVarint', () {
      // Test that a varint with too many bytes throws FormatException
      // Create 10 bytes all with continuation bit set - exceeds 64-bit capacity
      // A valid varint64 can be at most 10 bytes (70 bits can encode 64-bit value)
      final malformed = List.filled(11, 0x80);  // 11 bytes all with continuation bit
      expect(
        () => EncodedInts.readVarint64(malformed, 0),
        throwsA(isA<FormatException>()),
      );
    });
  });
}

