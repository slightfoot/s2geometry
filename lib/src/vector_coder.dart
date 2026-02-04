// Copyright 2019 Google Inc. All Rights Reserved.
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
import 'dart:math';

import 'in_memory_output_stream.dart';
import 'primitive_arrays.dart';
import 's2_coder.dart';
import 'uint_vector_coder.dart';

/// An encoder/decoder of [List]s. Decoding is on-demand, so [isLazy] is true.
///
/// The basic [encode] method uses a new [InMemoryOutputStream] for temporary
/// storage. Callers may use [encodeWithBuffer] to supply a different buffer
/// for reuse.
class VectorCoder<T> extends S2Coder<List<T>> {
  /// An encoder/decoder of `List<List<int>>` (byte arrays).
  static final VectorCoder<List<int>> BYTE_ARRAY = VectorCoder<List<int>>(
    _ByteArrayCoder(),
  );

  /// An encoder/decoder of `List<String>`.
  static final VectorCoder<String> STRING = VectorCoder<String>(
    _StringCoder(),
  );

  // TODO: Add FAST_SHAPE and COMPACT_SHAPE after S2TaggedShapeCoder is ported

  final S2Coder<T> _coder;

  /// Constructs a [VectorCoder] which encodes/decodes elements with [coder].
  VectorCoder(this._coder);

  @override
  List<int> encode(List<T> values) {
    return encodeWithBuffer(values, ByteArrayInMemoryOutputStream());
  }

  /// Encodes the given [values] using a provided [buffer] for temporary storage.
  /// This may be used by clients who want to reuse a buffer for repeated encoding.
  List<int> encodeWithBuffer(List<T> values, InMemoryOutputStream buffer) {
    final offsets = <int>[];

    for (final value in values) {
      final encoded = _coder.encode(value);
      buffer.writeBytes(encoded);
      offsets.add(buffer.size);
    }

    final result = <int>[];
    final encodedOffsets = UintVectorCoder.UINT64.encode(_ListLongs(offsets));
    result.addAll(encodedOffsets);
    result.addAll(buffer.toBytes());

    return result;
  }

  @override
  EncodedList<T> decode(Bytes data, Cursor cursor) {
    try {
      return _decodeInternal(data, cursor);
    } on RangeError catch (e) {
      throw FormatException('Insufficient or invalid input bytes: $e');
    }
  }

  EncodedList<T> _decodeInternal(Bytes data, Cursor cursor) {
    final offsets = UintVectorCoder.UINT64.decode(data, cursor);
    final offset = cursor.position;
    cursor.position += (offsets.length > 0 ? offsets.get(offsets.length - 1) : 0);

    return _EncodedListImpl<T>(data, offsets, offset, _coder);
  }

  @override
  bool get isLazy => true;
}

/// An encoded list that decodes elements on demand.
abstract class EncodedList<T> implements List<T> {
  /// The encoded size of the given element in bytes.
  int encodedSize(int index);
}

class _EncodedListImpl<T> extends EncodedList<T> {
  final Bytes _data;
  final Longs _offsets;
  final int _offset;
  final S2Coder<T> _coder;

  _EncodedListImpl(this._data, this._offsets, this._offset, this._coder);

  @override
  T operator [](int index) {
    final start = (index == 0) ? 0 : _offsets.get(index - 1);
    final end = _offsets.get(index);
    try {
      return _coder.decode(_data, _data.cursor(_offset + start, _offset + end));
    } on FormatException {
      throw ArgumentError('Underlying decode error');
    }
  }

  @override
  int get length => _offsets.length;

  @override
  int encodedSize(int index) {
    final start = (index == 0) ? 0 : _offsets.get(index - 1);
    final end = _offsets.get(index);
    return end - start;
  }

  // Required List methods that delegate to the basic interface
  @override
  void operator []=(int index, T value) =>
      throw UnsupportedError('Cannot modify EncodedList');

  @override
  set length(int newLength) =>
      throw UnsupportedError('Cannot modify EncodedList');

  @override
  void add(T value) => throw UnsupportedError('Cannot modify EncodedList');

  @override
  void addAll(Iterable<T> iterable) =>
      throw UnsupportedError('Cannot modify EncodedList');

  // Implement remaining List interface methods using mixin-style iteration

  @override
  bool any(bool Function(T) test) {
    for (int i = 0; i < length; i++) {
      if (test(this[i])) return true;
    }
    return false;
  }

  @override
  List<R> cast<R>() => List.castFrom<T, R>(this);

  @override
  bool contains(Object? element) {
    for (int i = 0; i < length; i++) {
      if (this[i] == element) return true;
    }
    return false;
  }

  @override
  T elementAt(int index) => this[index];

  @override
  bool every(bool Function(T) test) {
    for (int i = 0; i < length; i++) {
      if (!test(this[i])) return false;
    }
    return true;
  }

  @override
  Iterable<R> expand<R>(Iterable<R> Function(T) f) sync* {
    for (int i = 0; i < length; i++) {
      yield* f(this[i]);
    }
  }

  @override
  T get first => this[0];

  @override
  set first(T value) => throw UnsupportedError('Cannot modify EncodedList');

  @override
  T firstWhere(bool Function(T) test, {T Function()? orElse}) {
    for (int i = 0; i < length; i++) {
      final e = this[i];
      if (test(e)) return e;
    }
    if (orElse != null) return orElse();
    throw StateError('No element');
  }

  @override
  R fold<R>(R initialValue, R Function(R, T) combine) {
    var value = initialValue;
    for (int i = 0; i < length; i++) {
      value = combine(value, this[i]);
    }
    return value;
  }

  @override
  Iterable<T> followedBy(Iterable<T> other) sync* {
    for (int i = 0; i < length; i++) {
      yield this[i];
    }
    yield* other;
  }

  @override
  void forEach(void Function(T) action) {
    for (int i = 0; i < length; i++) {
      action(this[i]);
    }
  }

  @override
  bool get isEmpty => length == 0;

  @override
  bool get isNotEmpty => length != 0;

  @override
  Iterator<T> get iterator => _EncodedListIterator<T>(this);

  @override
  String join([String separator = '']) {
    final buffer = StringBuffer();
    for (int i = 0; i < length; i++) {
      if (i > 0) buffer.write(separator);
      buffer.write(this[i]);
    }
    return buffer.toString();
  }

  @override
  T get last => this[length - 1];

  @override
  set last(T value) => throw UnsupportedError('Cannot modify EncodedList');

  @override
  T lastWhere(bool Function(T) test, {T Function()? orElse}) {
    for (int i = length - 1; i >= 0; i--) {
      final e = this[i];
      if (test(e)) return e;
    }
    if (orElse != null) return orElse();
    throw StateError('No element');
  }

  @override
  Iterable<R> map<R>(R Function(T) f) sync* {
    for (int i = 0; i < length; i++) {
      yield f(this[i]);
    }
  }

  @override
  T reduce(T Function(T, T) combine) {
    if (isEmpty) throw StateError('No element');
    var value = this[0];
    for (int i = 1; i < length; i++) {
      value = combine(value, this[i]);
    }
    return value;
  }

  @override
  T get single {
    if (length != 1) throw StateError('Not a single element');
    return this[0];
  }

  @override
  T singleWhere(bool Function(T) test, {T Function()? orElse}) {
    T? found;
    bool foundOne = false;
    for (int i = 0; i < length; i++) {
      final e = this[i];
      if (test(e)) {
        if (foundOne) throw StateError('Too many elements');
        found = e;
        foundOne = true;
      }
    }
    if (foundOne) return found as T;
    if (orElse != null) return orElse();
    throw StateError('No element');
  }

  @override
  Iterable<T> skip(int count) sync* {
    for (int i = count; i < length; i++) {
      yield this[i];
    }
  }

  @override
  Iterable<T> skipWhile(bool Function(T) test) sync* {
    bool skipping = true;
    for (int i = 0; i < length; i++) {
      final e = this[i];
      if (skipping && test(e)) continue;
      skipping = false;
      yield e;
    }
  }

  @override
  Iterable<T> take(int count) sync* {
    int n = 0;
    for (int i = 0; i < length && n < count; i++, n++) {
      yield this[i];
    }
  }

  @override
  Iterable<T> takeWhile(bool Function(T) test) sync* {
    for (int i = 0; i < length; i++) {
      final e = this[i];
      if (!test(e)) break;
      yield e;
    }
  }

  @override
  List<T> toList({bool growable = true}) {
    final result = <T>[];
    for (int i = 0; i < length; i++) {
      result.add(this[i]);
    }
    return growable ? result : List.unmodifiable(result);
  }

  @override
  Set<T> toSet() {
    final result = <T>{};
    for (int i = 0; i < length; i++) {
      result.add(this[i]);
    }
    return result;
  }

  @override
  Iterable<T> where(bool Function(T) test) sync* {
    for (int i = 0; i < length; i++) {
      final e = this[i];
      if (test(e)) yield e;
    }
  }

  @override
  Iterable<R> whereType<R>() sync* {
    for (int i = 0; i < length; i++) {
      final e = this[i];
      if (e is R) yield e;
    }
  }

  // List-specific methods

  @override
  Map<int, T> asMap() {
    return {for (int i = 0; i < length; i++) i: this[i]};
  }

  @override
  void clear() => throw UnsupportedError('Cannot modify EncodedList');

  @override
  void fillRange(int start, int end, [T? fillValue]) =>
      throw UnsupportedError('Cannot modify EncodedList');

  @override
  Iterable<T> getRange(int start, int end) sync* {
    for (int i = start; i < end; i++) {
      yield this[i];
    }
  }

  @override
  int indexOf(T element, [int start = 0]) {
    for (int i = start; i < length; i++) {
      if (this[i] == element) return i;
    }
    return -1;
  }

  @override
  int indexWhere(bool Function(T) test, [int start = 0]) {
    for (int i = start; i < length; i++) {
      if (test(this[i])) return i;
    }
    return -1;
  }

  @override
  void insert(int index, T element) =>
      throw UnsupportedError('Cannot modify EncodedList');

  @override
  void insertAll(int index, Iterable<T> iterable) =>
      throw UnsupportedError('Cannot modify EncodedList');

  @override
  int lastIndexOf(T element, [int? start]) {
    start ??= length - 1;
    for (int i = start; i >= 0; i--) {
      if (this[i] == element) return i;
    }
    return -1;
  }

  @override
  int lastIndexWhere(bool Function(T) test, [int? start]) {
    start ??= length - 1;
    for (int i = start; i >= 0; i--) {
      if (test(this[i])) return i;
    }
    return -1;
  }

  @override
  bool remove(Object? value) =>
      throw UnsupportedError('Cannot modify EncodedList');

  @override
  T removeAt(int index) => throw UnsupportedError('Cannot modify EncodedList');

  @override
  T removeLast() => throw UnsupportedError('Cannot modify EncodedList');

  @override
  void removeRange(int start, int end) =>
      throw UnsupportedError('Cannot modify EncodedList');

  @override
  void removeWhere(bool Function(T) test) =>
      throw UnsupportedError('Cannot modify EncodedList');

  @override
  void replaceRange(int start, int end, Iterable<T> replacements) =>
      throw UnsupportedError('Cannot modify EncodedList');

  @override
  void retainWhere(bool Function(T) test) =>
      throw UnsupportedError('Cannot modify EncodedList');

  @override
  Iterable<T> get reversed sync* {
    for (int i = length - 1; i >= 0; i--) {
      yield this[i];
    }
  }

  @override
  void setAll(int index, Iterable<T> iterable) =>
      throw UnsupportedError('Cannot modify EncodedList');

  @override
  void setRange(int start, int end, Iterable<T> iterable, [int skipCount = 0]) =>
      throw UnsupportedError('Cannot modify EncodedList');

  @override
  void shuffle([Random? random]) =>
      throw UnsupportedError('Cannot modify EncodedList');

  @override
  void sort([int Function(T, T)? compare]) =>
      throw UnsupportedError('Cannot modify EncodedList');

  @override
  List<T> sublist(int start, [int? end]) {
    end ??= length;
    final result = <T>[];
    for (int i = start; i < end; i++) {
      result.add(this[i]);
    }
    return result;
  }

  @override
  List<T> operator +(List<T> other) {
    return [...toList(), ...other];
  }
}

class _EncodedListIterator<T> implements Iterator<T> {
  final _EncodedListImpl<T> _list;
  int _index = -1;

  _EncodedListIterator(this._list);

  @override
  T get current => _list[_index];

  @override
  bool moveNext() {
    _index++;
    return _index < _list.length;
  }
}

/// Helper Longs implementation backed by a List<int>.
class _ListLongs extends Longs {
  final List<int> _values;

  _ListLongs(this._values);

  @override
  int get(int position) => _values[position];

  @override
  int get length => _values.length;
}

/// Coder for byte arrays.
class _ByteArrayCoder extends S2Coder<List<int>> {
  @override
  List<int> encode(List<int> value) => value;

  @override
  List<int> decode(Bytes data, Cursor cursor) {
    final remaining = cursor.remaining;
    if (remaining > 0x7FFFFFFF) {
      throw FormatException('Cannot decode ${remaining} bytes');
    }
    final result = <int>[];
    try {
      for (int i = 0; i < remaining; i++) {
        result.add(data.get(cursor.position++));
      }
    } on RangeError {
      throw FormatException(
          "'data' and 'cursor' are out of sync. Expected to read $remaining bytes.");
    }
    return result;
  }

  @override
  bool get isLazy => false;
}

/// Coder for strings.
class _StringCoder extends S2Coder<String> {
  @override
  List<int> encode(String value) => utf8.encode(value);

  @override
  String decode(Bytes data, Cursor cursor) {
    final remaining = cursor.remaining;
    if (remaining > 0x7FFFFFFF) {
      throw FormatException('Cannot decode ${remaining} bytes');
    }
    final bytes = <int>[];
    for (int i = 0; i < remaining; i++) {
      bytes.add(data.get(cursor.position++));
    }
    return utf8.decode(bytes);
  }

  @override
  bool get isLazy => false;
}

