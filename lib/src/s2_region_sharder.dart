// Copyright 2022 Google Inc.
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

import 's2_cell.dart';
import 's2_cell_index.dart';
import 's2_cell_union.dart';
import 's2_region.dart';

/// A sharding function that provides shard IDs whose boundaries intersect an
/// [S2Region]. This class is especially suited to testing regions against
/// shards that are usually very different in size from the regions; in that
/// case, [S2CellUnion] coverings of the region tend to cover too much area
/// (any simple covering of the Pacific Ocean for example) or too complex
/// (small regions are often contained by a single cell of the shard's
/// covering).
class S2RegionSharder {
  final S2CellIndex _index;

  /// Creates a new sharder.
  ///
  /// [boundaries] are the boundaries of each shard indexed by shard ID.
  factory S2RegionSharder(List<S2CellUnion> boundaries) {
    final index = S2CellIndex();
    for (int i = 0; i < boundaries.length; i++) {
      index.addCellUnion(boundaries[i], i);
    }
    index.build();
    return S2RegionSharder.fromIndex(index);
  }

  /// Creates a new sharder from the given index.
  S2RegionSharder.fromIndex(this._index);

  /// Returns the underlying index.
  S2CellIndex get index => _index;

  /// Returns an index into the original list of [S2CellUnion] given to the
  /// constructor, which indicates the shard whose covering has the most
  /// overlap with [region], or returns [defaultShard] if no shard overlaps
  /// the region.
  int getMostIntersectingShard(S2Region region, int defaultShard) {
    // Return the best shard by intersection area.
    final shardCoverings = _intersections(region);
    int bestShard = defaultShard;
    int bestSum = 0;
    // Sort the keys to make the selection deterministic.
    final sortedKeys = shardCoverings.keys.toList()..sort();
    for (final shardId in sortedKeys) {
      final shardCovering = shardCoverings[shardId]!;
      int sum = 0;
      for (final id in shardCovering.cellIds) {
        sum += id.lowestOnBit;
      }
      if (sum > bestSum) {
        bestShard = shardId;
        bestSum = sum;
      }
    }
    return bestShard;
  }

  /// Returns a list of shard numbers which intersect with [region]. Shard
  /// numbers are not guaranteed to be sorted in any particular order. If no
  /// shards overlap, returns an empty list.
  Iterable<int> getIntersectingShards(S2Region region) {
    return _intersections(region).keys;
  }

  Map<int, S2CellUnion> _intersections(S2Region region) {
    // Compute the intersection between the region covering and each shard covering.
    final regionCovering = S2CellUnion();
    region.getCellUnionBound(regionCovering.cellIds);
    final Map<int, S2CellUnion> shardCoverings = {};
    _index.visitIntersectingCells(regionCovering, (cell, shardId) {
      var shard = shardCoverings[shardId];
      if (shard == null) {
        shard = S2CellUnion();
        shardCoverings[shardId] = shard;
      }
      shard.cellIds.add(cell);
      return true;
    });

    // The fast covering is very loose, but typically it only intersects one shard.
    if (shardCoverings.length == 1) {
      return shardCoverings;
    }

    // Clip each shard to the region.
    final tempIntersection = S2CellUnion();
    for (final shardCovering in shardCoverings.values) {
      // Get the intersection since the shard's covering may have smaller cells than the region's.
      // We know the region covering is normalized but must normalize each shard covering first.
      shardCovering.normalize();
      tempIntersection.getIntersection(shardCovering, regionCovering);
      // Remove cells that don't intersect the region.
      tempIntersection.cellIds.removeWhere((id) => !region.mayIntersect(S2Cell(id)));
      // Save the clipped shard covering.
      shardCovering.cellIds.clear();
      shardCovering.cellIds.addAll(tempIntersection.cellIds);
    }
    shardCoverings.removeWhere((k, v) => v.isEmpty);
    return shardCoverings;
  }
}

