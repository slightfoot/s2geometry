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

import 'dart:typed_data';
import 'package:s2geometry/s2geometry.dart';
import 'package:test/test.dart';

void main() {
  group('LittleEndianOutput', () {
    test('writeByte', () {
      final output = LittleEndianOutput();
      output.writeByte(0x42);
      expect(output.toBytes(), equals([0x42]));
    });

    test('writeBytes', () {
      final output = LittleEndianOutput();
      output.writeBytes([0x01, 0x02, 0x03]);
      expect(output.toBytes(), equals([0x01, 0x02, 0x03]));
    });

    test('writeInt', () {
      final output = LittleEndianOutput();
      output.writeInt(0x12345678);
      expect(output.toBytes(), equals([0x78, 0x56, 0x34, 0x12]));
    });

    test('writeLong', () {
      final output = LittleEndianOutput();
      output.writeLong(0x123456789ABCDEF0);
      expect(output.toBytes(),
          equals([0xF0, 0xDE, 0xBC, 0x9A, 0x78, 0x56, 0x34, 0x12]));
    });

    test('writeFloat', () {
      final output = LittleEndianOutput();
      output.writeFloat(1.0);
      // 1.0 in IEEE 754 little endian is [0x00, 0x00, 0x80, 0x3F]
      expect(output.toBytes(), equals([0x00, 0x00, 0x80, 0x3F]));
    });

    test('writeDouble', () {
      final output = LittleEndianOutput();
      output.writeDouble(1.0);
      // 1.0 in IEEE 754 double little endian is [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xF0, 0x3F]
      expect(output.toBytes(),
          equals([0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xF0, 0x3F]));
    });

    test('writeVarint32', () {
      final output = LittleEndianOutput();
      output.writeVarint32(127);
      expect(output.toBytes(), equals([127]));
    });

    test('writeVarint64', () {
      final output = LittleEndianOutput();
      output.writeVarint64(300);
      // 300 = 0x12C = 0x01 | 0x2C
      expect(output.toBytes(), equals([0xAC, 0x02]));
    });

    test('clear', () {
      final output = LittleEndianOutput();
      output.writeByte(0x42);
      output.clear();
      expect(output.length, equals(0));
    });
  });

  group('LittleEndianInput', () {
    test('readByte', () {
      final input = LittleEndianInput([0x42]);
      expect(input.readByte(), equals(0x42));
    });

    test('readBytes', () {
      final input = LittleEndianInput([0x01, 0x02, 0x03]);
      expect(input.readBytes(3), equals([0x01, 0x02, 0x03]));
    });

    test('readInt', () {
      final input = LittleEndianInput([0x78, 0x56, 0x34, 0x12]);
      expect(input.readInt(), equals(0x12345678));
    });

    test('readLong', () {
      final input = LittleEndianInput(
          [0xF0, 0xDE, 0xBC, 0x9A, 0x78, 0x56, 0x34, 0x12]);
      expect(input.readLong(), equals(0x123456789ABCDEF0));
    });

    test('readFloat', () {
      final input = LittleEndianInput([0x00, 0x00, 0x80, 0x3F]);
      expect(input.readFloat(), equals(1.0));
    });

    test('readDouble', () {
      final input = LittleEndianInput(
          [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xF0, 0x3F]);
      expect(input.readDouble(), equals(1.0));
    });

    test('readVarint32', () {
      final input = LittleEndianInput([127]);
      expect(input.readVarint32(), equals(127));
    });

    test('readVarint64', () {
      final input = LittleEndianInput([0xAC, 0x02]);
      expect(input.readVarint64(), equals(300));
    });

    test('remaining and isEmpty', () {
      final input = LittleEndianInput([0x01, 0x02, 0x03]);
      expect(input.remaining, equals(3));
      expect(input.isEmpty, isFalse);
      input.readByte();
      expect(input.remaining, equals(2));
      input.readBytes(2);
      expect(input.isEmpty, isTrue);
    });

    test('position', () {
      final input = LittleEndianInput([0x01, 0x02, 0x03]);
      expect(input.position, equals(0));
      input.readByte();
      expect(input.position, equals(1));
      input.position = 0;
      expect(input.readByte(), equals(0x01));
    });

    test('throws FormatException on EOF', () {
      final input = LittleEndianInput([0x01]);
      input.readByte();
      expect(() => input.readByte(), throwsFormatException);
    });
  });

  group('Round-trip', () {
    test('int round-trip positive', () {
      final output = LittleEndianOutput();
      output.writeInt(0x12345678);
      final input = LittleEndianInput(output.toBytes());
      expect(input.readInt(), equals(0x12345678));
    });

    test('int round-trip negative', () {
      final output = LittleEndianOutput();
      // In Dart, -1 as a 32-bit value is 0xFFFFFFFF
      output.writeInt(-1);
      final input = LittleEndianInput(output.toBytes());
      // readInt returns a 32-bit value, which is 0xFFFFFFFF
      expect(input.readInt(), equals(0xFFFFFFFF));
    });

    test('long round-trip', () {
      final output = LittleEndianOutput();
      output.writeLong(-1);
      final input = LittleEndianInput(output.toBytes());
      expect(input.readLong(), equals(-1));
    });

    test('double round-trip', () {
      final output = LittleEndianOutput();
      output.writeDouble(3.14159265358979323);
      final input = LittleEndianInput(output.toBytes());
      expect(input.readDouble(), closeTo(3.14159265358979323, 1e-15));
    });

    test('float round-trip', () {
      final output = LittleEndianOutput();
      output.writeFloat(3.14159);
      final input = LittleEndianInput(output.toBytes());
      expect(input.readFloat(), closeTo(3.14159, 1e-5));
    });
  });
}

