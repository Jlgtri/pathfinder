part of '../solvers.dart';

/// The unit of work exposed to the UI while replaying A*.
enum AStarOperation { expand, inspect }

/// One observable operation of the A* search.
final class AStarTraceEntry {
  const new({
    required this.kind,
    required this.current,
    required this.candidate,
    required this.accepted,
    required this.expanded,
    required this.inspected,
    required this.improved,
    required this.frontierSize,
    required this.g,
    required this.h,
  });

  final AStarOperation kind;
  final GridPoint current;
  final GridPoint? candidate;
  final bool accepted;

  /// Cumulative A* counters, at this particular operation.
  final int expanded;
  final int inspected;
  final int improved;
  final int frontierSize;

  /// Scores for current node on expand, or proposed candidate on inspect.
  final int g;
  final int h;
  int get f => g + h;
}

/// Full completed search, with exact totals suitable for slow-motion playback.
final class AStarTraceResult {
  const new({
    required this.operations,
    required this.path,
    required this.walkableCells,
  });

  final List<AStarTraceEntry> operations;
  final List<GridPoint> path;
  final int walkableCells;

  int get totalComputations => operations.length;
}

/// Generates an accurate A* trace before replaying it in the UI.
/// Uses 8-directional, adjacent-cell, unit-cost movement.
final class AStarTraceSolver {
  const new();

  static const List<(int, int)> _directions = <(int, int)>[
    (-1, -1),
    (0, -1),
    (1, -1),
    (-1, 0),
    (1, 0),
    (-1, 1),
    (0, 1),
    (1, 1),
  ];

  AStarTraceResult trace(PathTask task) {
    final List<String> field = task.field;
    final int size = field.length;

    if (size < 2 ||
        size >= 100 ||
        field.any(
          (String row) =>
              row.length != size ||
              row
                  .split('')
                  .any(
                    (String character) => character != '.' && character != 'X',
                  ),
        )) {
      throw const FormatException('Invalid square grid');
    }

    bool inside(int x, int y) => x >= 0 && y >= 0 && x < size && y < size;
    bool walkable(int x, int y) => inside(x, y) && field[y][x] == '.';
    int index(int x, int y) => y * size + x;
    GridPoint point(int index) => GridPoint(x: index % size, y: index ~/ size);
    int h(int x, int y) => max((task.end.x - x).abs(), (task.end.y - y).abs());

    if (!walkable(task.start.x, task.start.y) ||
        !walkable(task.end.x, task.end.y)) {
      throw ArgumentError('Start or end is blocked or outside the grid');
    }

    final int start = index(task.start.x, task.start.y);
    final int end = index(task.end.x, task.end.y);
    final int length = size * size;
    final List<int> gScores = List<int>.filled(length, 1 << 30);
    final List<int> parents = List<int>.filled(length, -1);
    final List<bool> closed = List<bool>.filled(length, false);
    final List<AStarTraceEntry> operations = <AStarTraceEntry>[];
    final int walkableCells = field.fold<int>(
      0,
      (int sum, String row) => sum + '.'.allMatches(row).length,
    );

    int sequence = 0;
    int expanded = 0;
    int inspected = 0;
    int improved = 0;

    final SplayTreeSet<_AStarTraceNode> open = SplayTreeSet<_AStarTraceNode>((
      _AStarTraceNode a,
      _AStarTraceNode b,
    ) {
      final int byF = a.f.compareTo(b.f);
      if (byF != 0) return byF;
      final int byH = a.h.compareTo(b.h);
      if (byH != 0) return byH;
      return a.order.compareTo(b.order);
    });

    gScores[start] = 0;
    open.add(
      _AStarTraceNode(
        index: start,
        g: 0,
        h: h(task.start.x, task.start.y),
        order: sequence++,
      ),
    );

    while (open.isNotEmpty) {
      final _AStarTraceNode node = open.first;
      open.remove(node);
      if (closed[node.index] || node.g != gScores[node.index]) continue;

      closed[node.index] = true;
      expanded++;
      final GridPoint current = point(node.index);
      operations.add(
        AStarTraceEntry(
          kind: AStarOperation.expand,
          current: current,
          candidate: null,
          accepted: true,
          expanded: expanded,
          inspected: inspected,
          improved: improved,
          frontierSize: open.length,
          g: node.g,
          h: node.h,
        ),
      );

      if (node.index == end) {
        final List<GridPoint> path = <GridPoint>[];
        int cursor = end;
        while (cursor != -1) {
          path.add(point(cursor));
          cursor = parents[cursor];
        }
        return AStarTraceResult(
          operations: List<AStarTraceEntry>.unmodifiable(operations),
          path: List<GridPoint>.unmodifiable(path.reversed),
          walkableCells: walkableCells,
        );
      }

      for (final (int dx, int dy) in _directions) {
        final int nx = current.x + dx;
        final int ny = current.y + dy;
        if (!inside(nx, ny)) continue;

        inspected++;
        final int candidateIndex = index(nx, ny);
        final int tentativeG = node.g + 1;
        final int candidateH = h(nx, ny);
        final bool accepted =
            walkable(nx, ny) &&
            !closed[candidateIndex] &&
            tentativeG < gScores[candidateIndex];

        if (accepted) {
          gScores[candidateIndex] = tentativeG;
          parents[candidateIndex] = node.index;
          improved++;
          open.add(
            _AStarTraceNode(
              index: candidateIndex,
              g: tentativeG,
              h: candidateH,
              order: sequence++,
            ),
          );
        }

        operations.add(
          AStarTraceEntry(
            kind: AStarOperation.inspect,
            current: current,
            candidate: GridPoint(x: nx, y: ny),
            accepted: accepted,
            expanded: expanded,
            inspected: inspected,
            improved: improved,
            frontierSize: open.length,
            g: tentativeG,
            h: candidateH,
          ),
        );
      }
    }

    throw StateError('No path found for task ${task.id}');
  }
}

final class _AStarTraceNode {
  const new({
    required this.index,
    required this.g,
    required this.h,
    required this.order,
  });

  final int index;
  final int g;
  final int h;
  final int order;
  int get f => g + h;
}
