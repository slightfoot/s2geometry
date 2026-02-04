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

import 'dart:convert';
import 'dart:typed_data';

import 'encoded_ints.dart';
import 'primitive_arrays.dart';

/// An interface for encoding and decoding values.
///
/// This is one of several helper classes that allow complex data structures to be
/// initialized from an encoded format in constant time and then decoded on demand.
/// This can be a big performance advantage when only a small part of the data
/// structure is actually used.
abstract class S2Coder<T> {
  /// A coder of an unboxed varint.
  static final S2Coder<int> unboxedVarint = _UnboxedVarintCoder();

  /// An encoder of List<int> that writes the varint length of the byte array before it.
  static final S2Coder<List<int>> bytes = _BytesCoder();

  /// A delimited string coder that converts to/from UTF8 and delegates to [bytes].
  static final S2Coder<String> string = bytes.delegating(
    (value) => utf8.encode(value),
    (b) => utf8.decode(b),
  );

  /// Encodes [value] to a byte list.
  List<int> encode(T value);

  /// Decodes a value of type [T] from [data] starting at [cursor.position].
  /// [cursor.position] is updated to the position of the first byte in [data]
  /// following the encoded value.
  ///
  /// Warning: If [isLazy] is true, the S2Coder may keep a reference to the
  /// provided 'data' after decode() has returned. Callers should ensure that
  /// the bytes given to decode() are unaltered for as long as the returned [T]
  /// is in use.
  T decode(Bytes data, Cursor cursor);

  /// As [decode] but reads from position 0 in [data].
  T decodeBytes(Bytes data) => decode(data, data.cursor());

  /// Must return true if the implementation of [decode] retains a reference to
  /// the buffer it is given. Lazy decoding is usually cheaper at decode time,
  /// but may be more expensive if the entire object will be inspected.
  bool get isLazy => true;

  /// As [encode] but wraps any exceptions in [ArgumentError].
  List<int> unsafeEncode(T value) {
    try {
      return encode(value);
    } catch (e) {
      throw ArgumentError(e.toString());
    }
  }

  /// As [decodeBytes] but wraps any exceptions in [ArgumentError].
  T unsafeDecode(Bytes data) {
    try {
      return decodeBytes(data);
    } catch (e) {
      throw ArgumentError(e.toString());
    }
  }

  /// Returns a coder that delegates to this coder via the given encode/decode
  /// transforms.
  S2Coder<U> delegating<U>(
    List<int> Function(U) encodeFunc,
    U Function(List<int>) decodeFunc,
  ) {
    return _DelegatingCoder<U, T>(this, encodeFunc, decodeFunc);
  }
}

/// Coder for varint-encoded integers.
class _UnboxedVarintCoder extends S2Coder<int> {
  @override
  List<int> encode(int value) {
    final result = <int>[];
    EncodedInts.writeVarint64(result, value);
    return result;
  }

  @override
  int decode(Bytes data, Cursor cursor) {
    return data.readVarint64(cursor);
  }

  @override
  bool get isLazy => false;
}

/// Coder for byte arrays with varint length prefix.
class _BytesCoder extends S2Coder<List<int>> {
  @override
  List<int> encode(List<int> bytes) {
    final result = <int>[];
    EncodedInts.writeVarint64(result, bytes.length);
    result.addAll(bytes);
    return result;
  }

  @override
  List<int> decode(Bytes data, Cursor cursor) {
    final length = data.readVarint32(cursor);
    if (length > cursor.remaining) {
      throw ArgumentError('Length too long');
    }
    final b = Uint8List(length);
    for (int i = 0; i < length; i++) {
      b[i] = data.get(cursor.position++);
    }
    return b;
  }

  @override
  bool get isLazy => false;
}

/// A coder that delegates to another coder with transform functions.
class _DelegatingCoder<U, T> extends S2Coder<U> {
  final S2Coder<T> _base;
  final List<int> Function(U) _encodeFunc;
  final U Function(List<int>) _decodeFunc;

  _DelegatingCoder(this._base, this._encodeFunc, this._decodeFunc);

  @override
  List<int> encode(U value) {
    return _base.encode(_encodeFunc(value) as T);
  }

  @override
  U decode(Bytes data, Cursor cursor) {
    final decoded = _base.decode(data, cursor);
    return _decodeFunc(decoded as List<int>);
  }

  @override
  bool get isLazy => _base.isLazy;
}

