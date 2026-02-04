// Copyright 2022 Google Inc. All Rights Reserved.
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

import 'dart:math' as math;

/// Any implementation of SortableCollection can be sorted by Sorter.
abstract class SortableCollection {
  /// True if the element at leftIndex should be ordered before the element at rightIndex.
  bool less(int leftIndex, int rightIndex);

  /// Exchanges the elements at the given indices.
  void swap(int leftIndex, int rightIndex);

  /// Returns the number of elements in this sortable.
  int get size;

  /// Sorts this collection.
  void sort() {
    if (size > 1) {
      Sorter.sortRange(this, 0, size - 1);
    }
  }

  /// Eliminates all elements at index 'start' and later.
  void truncate(int start);

  /// Removes adjacent duplicates from this collection.
  void unique() {
    final s = size;
    if (s <= 1) {
      return;
    }
    int dst = 0;
    for (int i = 1; i < s; i++) {
      if (less(dst, i)) {
        swap(++dst, i);
      }
    }
    truncate(dst + 1);
  }
}

/// An implementation of QuickSort for abstract collections implementing SortableCollection.
class Sorter {
  Sorter._();

  /// Sorts the contents of "data".
  static void sort(SortableCollection data) {
    sortRange(data, 0, data.size - 1);
  }

  /// Sorts the contents of data from index "left" to index "right" inclusive.
  static void sortRange(SortableCollection data, int left, int right) {
    while ((right - left) >= 8) {
      int pivot = _pickPivot(data, left, right);
      int pa = left;
      int pb = left;
      int pc = right;
      int pd = right;
      while (true) {
        while ((pb <= pc) && !data.less(pivot, pb)) {
          if (!data.less(pb, pivot)) {
            data.swap(pa, pb);
            pivot = pa++;
          }
          pb++;
        }
        while ((pb <= pc) && !data.less(pc, pivot)) {
          if (!data.less(pivot, pc)) {
            data.swap(pc, pd);
            pivot = pd--;
          }
          pc--;
        }
        if (pb > pc) {
          break;
        }
        if (pb == pivot) {
          pivot = pc;
        } else if (pc == pivot) {
          pivot = pb;
        }
        data.swap(pb, pc);
        pb++;
        pc--;
      }
      int s;
      s = math.min(pa - left, pb - pa);
      _swapRange(data, left, pb - s, s);
      s = math.min(pd - pc, right - pd);
      _swapRange(data, pb, right + 1 - s, s);
      int l1 = left;
      int r1 = left + (pb - pa) - 1;
      int l2 = right + 1 - (pd - pc);
      int r2 = right;
      if ((r1 - l1) < (r2 - l2)) {
        left = l2;
        right = r2;
      } else {
        left = l1;
        right = r1;
        l1 = l2;
        r1 = r2;
      }
      if (l1 < r1) {
        sortRange(data, l1, r1);
      }
    }
    _insertionSort(data, left, right);
  }

  static void _insertionSort(SortableCollection data, int left, int right) {
    for (int i = left; i <= right; i++) {
      for (int j = i; j > left && data.less(j, j - 1); j--) {
        data.swap(j, j - 1);
      }
    }
  }

  static int _pickPivot(SortableCollection data, int left, int right) {
    if ((right - left + 1) > 100) {
      int d = (right - left) ~/ 8;
      int a = _median(data, left + 0 * d, left + 1 * d, left + 2 * d);
      int b = _median(data, left + 3 * d, left + 4 * d, left + 5 * d);
      int c = _median(data, left + 6 * d, left + 7 * d, left + 8 * d);
      return _median(data, a, b, c);
    } else {
      return _median(data, left, (left + right) ~/ 2, right);
    }
  }

  static int _median(SortableCollection data, int a, int b, int c) {
    return (data.less(a, b)
        ? (data.less(b, c) ? b : (data.less(a, c) ? c : a))
        : (data.less(c, b) ? b : (data.less(c, a) ? c : a)));
  }

  static void _swapRange(SortableCollection data, int p1, int p2, int n) {
    for (int i = 0; i < n; i++) {
      data.swap(p1 + i, p2 + i);
    }
  }
}

