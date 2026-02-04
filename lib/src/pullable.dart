// Copyright 2024 Google Inc. All Rights Reserved.
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

import 'dart:collection';

import 'sorter.dart';

/// PullIterator provides iteration over the entries of a Pullable.
abstract class PullIterator {
  /// Returns false if there is no next value available, otherwise updates
  /// the mutable T with a copy of the next element and returns true.
  bool pull();
}

/// A pull model for accessing encoded data.
abstract class Pullable<T> {
  /// Returns a PullIterator over the collection that will repeatedly fill the given value.
  PullIterator iterator(T value);

  /// Repeatedly pulls a new value into the given "result" and then runs the given action.
  void forEach(T result, void Function() action) {
    final it = iterator(result);
    while (it.pull()) {
      action();
    }
  }
}

/// PullCollection extends Pullable. Similar to a java.util.Collection.
abstract class PullCollection<T> extends Pullable<T> {
  /// Returns an instance of T which is not a member of the collection.
  T newElement();

  /// Accepts a T previously returned by newElement() for reuse or cleanup.
  void destroyElement(T value) {}

  /// Ensure that at least 'capacity' entries can be stored without additional allocation.
  /// Returns true if storage was increased, false otherwise.
  bool ensureCapacity(int capacity);

  /// The number of elements in the collection.
  int get size;

  /// Returns true if the collection contains no elements.
  bool get isEmpty => size == 0;

  /// Removes all elements from the collection.
  void clear();

  /// Adds a copy of the given value to the collection.
  void add(T value);

  /// Adds copies of all the given values to the collection.
  void addAll(Pullable<T> values) {
    final val = newElement();
    final it = values.iterator(val);
    while (it.pull()) {
      add(val);
    }
    destroyElement(val);
  }
}

/// A PullList extends PullCollection to provide random access by index.
abstract class PullList<T> extends PullCollection<T> {
  /// Copies the value of the element at the given index into the given value.
  void get(int index, T value);

  /// Sets the value at the given index to a copy of the given value.
  void set(int index, T value);

  @override
  PullIterator iterator(T value) {
    return _PullListIterator(this, value);
  }

  /// Copies the value at fromIndex to toIndex.
  void copy(int fromIndex, int toIndex) {
    final tmp = newElement();
    get(fromIndex, tmp);
    set(toIndex, tmp);
    destroyElement(tmp);
  }

  /// Swaps the elements at indexA and indexB.
  void swap(int indexA, int indexB) {
    final tmp = newElement();
    get(indexA, tmp);
    copy(indexB, indexA);
    set(indexB, tmp);
    destroyElement(tmp);
  }

  /// Sorts the list using the given comparator.
  void sortWith(int Function(T left, T right) comparator) {
    final left = newElement();
    final right = newElement();
    Sorter.sort(_PullListSortable(this, left, right, comparator));
    destroyElement(left);
    destroyElement(right);
  }

  /// Makes this list have at most 'newSize' elements.
  void truncate(int newSize);

  /// Makes this list have at least 'newSize' elements.
  void enlarge(int newSize);

  /// Makes this list have exactly 'newSize' elements.
  void resize(int newSize) {
    if (newSize < size) {
      truncate(newSize);
    } else if (newSize > size) {
      enlarge(newSize);
    }
  }

  /// Provides a List view of the PullList.
  List<T> asList() => _PullListView(this);
}

class _PullListIterator<T> implements PullIterator {
  final PullList<T> _list;
  final T _value;
  int _index = 0;

  _PullListIterator(this._list, this._value);

  @override
  bool pull() {
    if (_index >= _list.size) {
      return false;
    }
    _list.get(_index, _value);
    _index++;
    return true;
  }
}

class _PullListSortable<T> extends SortableCollection {
  final PullList<T> _list;
  final T _left;
  final T _right;
  final int Function(T, T) _comparator;

  _PullListSortable(this._list, this._left, this._right, this._comparator);

  @override
  bool less(int leftIndex, int rightIndex) {
    _list.get(leftIndex, _left);
    _list.get(rightIndex, _right);
    return _comparator(_left, _right) < 0;
  }

  @override
  void swap(int leftIndex, int rightIndex) {
    _list.swap(leftIndex, rightIndex);
  }

  @override
  int get size => _list.size;

  @override
  void truncate(int start) {
    _list.truncate(start);
  }
}

class _PullListView<T> with ListMixin<T> {
  final PullList<T> _list;

  _PullListView(this._list);

  @override
  T operator [](int index) {
    final value = _list.newElement();
    _list.get(index, value);
    return value;
  }

  @override
  void operator []=(int index, T value) {
    _list.set(index, value);
  }

  @override
  int get length => _list.size;

  @override
  set length(int newLength) {
    _list.resize(newLength);
  }
}
