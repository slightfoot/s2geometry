// Copyright 2013 Google Inc.
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

import 'platform.dart';
import 's2_point.dart';

/// A simple dense matrix class.
class Matrix {
  final List<double> _values;
  final int _rows;
  final int _cols;

  /// Constructs a matrix from a series of column vectors.
  factory Matrix.fromCols(List<S2Point> columns) {
    final result = Matrix(3, columns.length);
    for (int row = 0; row < result._rows; row++) {
      for (int col = 0; col < result._cols; col++) {
        result.set(row, col, columns[col].get(row));
      }
    }
    return result;
  }

  /// Constructs a 2D matrix with given columns and values.
  factory Matrix.fromValues(int cols, List<double> values) {
    if (cols < 0) {
      throw ArgumentError('Negative cols not allowed.');
    }
    final rows = values.length ~/ cols;
    if (rows * cols != values.length) {
      throw ArgumentError("Values not an even multiple of 'cols'");
    }
    return Matrix._internal(rows, cols, List<double>.from(values));
  }

  /// Constructs a 2D matrix of a fixed size.
  Matrix(int rows, int cols)
      : _rows = rows,
        _cols = cols,
        _values = List<double>.filled(rows * cols, 0.0) {
    if (rows < 0) throw ArgumentError('Negative rows not allowed.');
    if (cols < 0) throw ArgumentError('Negative cols not allowed.');
  }

  Matrix._internal(this._rows, this._cols, this._values);

  /// Returns the outer product of two S2Point vectors.
  factory Matrix.fromOuter(S2Point ma, S2Point mb) {
    return Matrix.fromValues(3, [
      ma.x * mb.x, ma.x * mb.y, ma.x * mb.z, // mb.mul(ma.x)
      ma.y * mb.x, ma.y * mb.y, ma.y * mb.z, // mb.mul(ma.y)
      ma.z * mb.x, ma.z * mb.y, ma.z * mb.z, // mb.mul(ma.z)
    ]);
  }

  /// Returns the 3x3 identity matrix.
  factory Matrix.identity3x3() {
    return Matrix.fromValues(3, [
      1, 0, 0, //
      0, 1, 0, //
      0, 0, 1,
    ]);
  }

  /// Returns the number of rows in this matrix.
  int get rows => _rows;

  /// Returns the number of columns in this matrix.
  int get cols => _cols;

  /// Sets a value.
  void set(int row, int col, double value) {
    _values[row * _cols + col] = value;
  }

  /// Gets a value.
  double get(int row, int col) {
    return _values[row * _cols + col];
  }

  /// Returns the transpose of this matrix.
  Matrix transpose() {
    final result = Matrix(_cols, _rows);
    for (int row = 0; row < result._rows; row++) {
      for (int col = 0; col < result._cols; col++) {
        result.set(row, col, get(col, row));
      }
    }
    return result;
  }

  /// Returns a matrix that reflects a point across the plane defined by the
  /// given normal, which does not need to be unit-length.
  static Matrix householder(S2Point normal) {
    final unit = normal.normalize();
    return Matrix.identity3x3().sub(Matrix.fromOuter(unit, unit).multScalar(2));
  }

  /// Returns the result of adding the given matrix to this matrix.
  Matrix add(Matrix m) {
    assert(_rows == m._rows && _cols == m._cols);
    final result = Matrix(_rows, _cols);
    for (int row = 0; row < result._rows; row++) {
      for (int col = 0; col < result._cols; col++) {
        result.set(row, col, get(row, col) + m.get(row, col));
      }
    }
    return result;
  }

  /// Returns the result of subtracting the given matrix from this matrix.
  Matrix sub(Matrix m) {
    assert(_rows == m._rows && _cols == m._cols);
    final result = Matrix(_rows, _cols);
    for (int row = 0; row < result._rows; row++) {
      for (int col = 0; col < result._cols; col++) {
        result.set(row, col, get(row, col) - m.get(row, col));
      }
    }
    return result;
  }

  /// Returns the result of multiplying this matrix by the given matrix m.
  Matrix mult(Matrix m) {
    assert(_cols == m._rows);
    final result = Matrix(_rows, m._cols);
    for (int row = 0; row < result._rows; row++) {
      for (int col = 0; col < result._cols; col++) {
        double sum = 0;
        for (int i = 0; i < _cols; i++) {
          sum += get(row, i) * m.get(i, col);
        }
        result.set(row, col, sum);
      }
    }
    return result;
  }

  /// Returns the result of multiplying this 3x3 matrix by the given S2Point.
  S2Point multPoint(S2Point v) {
    assert(_rows == 3 && _cols == 3);
    return S2Point(
      get(0, 0) * v.get(0) + get(0, 1) * v.get(1) + get(0, 2) * v.get(2),
      get(1, 0) * v.get(0) + get(1, 1) * v.get(1) + get(1, 2) * v.get(2),
      get(2, 0) * v.get(0) + get(2, 1) * v.get(1) + get(2, 2) * v.get(2),
    );
  }

  /// Returns the result of multiplying this matrix by the given scalar k.
  Matrix multScalar(double k) {
    final result = Matrix(_rows, _cols);
    for (int row = 0; row < _rows; row++) {
      for (int col = 0; col < _cols; col++) {
        result.set(row, col, get(row, col) * k);
      }
    }
    return result;
  }

  /// Returns the vector of the given column. The matrix must have 3 rows.
  S2Point getCol(int col) {
    assert(_rows == 3);
    assert(0 <= col && col < _cols);
    return S2Point(_values[col], _values[_cols + col], _values[2 * _cols + col]);
  }

  @override
  bool operator ==(Object other) {
    if (other is! Matrix) return false;
    if (_rows != other._rows || _cols != other._cols) return false;
    for (int i = 0; i < _values.length; i++) {
      if (_values[i] != other._values[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode {
    int hash = 37 * _cols;
    for (int i = 0; i < _values.length; i++) {
      hash = 37 * hash + Platform.doubleHash(_values[i]);
    }
    return hash;
  }

  @override
  String toString() {
    final sb = StringBuffer();
    sb.write('Matrix(');
    sb.write(_rows);
    sb.write('x');
    sb.write(_cols);
    sb.write('): ');
    for (int row = 0; row < _rows; row++) {
      for (int col = 0; col < _cols; col++) {
        sb.write(get(row, col));
        sb.write(' ');
      }
      sb.write('\n');
    }
    return sb.toString();
  }
}

