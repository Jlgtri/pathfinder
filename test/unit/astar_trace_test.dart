import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:pathfinder/src/api.dart';
import 'package:pathfinder/src/solvers.dart';

void main() {
  const AStarTraceSolver solver = AStarTraceSolver();

  group('A* trace solver', () {
    test('finds an optimal 8-direction route with correct endpoints', () {
      const PathTask task = PathTask(
        id: 'diagonal',
        field: <String>['....', '.XX.', '....', '....'],
        start: GridPoint(x: 0, y: 3),
        end: GridPoint(x: 3, y: 0),
      );

      final AStarTraceResult trace = solver.trace(task);
      expect(trace.totalComputations, trace.operations.length);
      expect(trace.totalComputations, greaterThan(0));
      _checkRoute(task, trace.path);
      expect(trace.path.length - 1, _oracleShortestMoves(task));
      expect(trace.operations.first.kind, AStarOperation.expand);
      expect(trace.operations.first.expanded, 1);
    });

    test('records consistent operation counters and A* scores', () {
      const PathTask task = PathTask(
        id: 'metrics',
        field: <String>['...', '...', '...'],
        start: GridPoint(x: 0, y: 0),
        end: GridPoint(x: 2, y: 2),
      );

      final AStarTraceResult trace = solver.trace(task);
      int previousExpanded = 0;
      int previousInspected = 0;
      int previousImproved = 0;
      for (final AStarTraceEntry op in trace.operations) {
        expect(op.expanded, greaterThanOrEqualTo(previousExpanded));
        expect(op.inspected, greaterThanOrEqualTo(previousInspected));
        expect(op.improved, greaterThanOrEqualTo(previousImproved));
        expect(op.f, op.g + op.h);
        expect(op.frontierSize, greaterThanOrEqualTo(0));
        previousExpanded = op.expanded;
        previousInspected = op.inspected;
        previousImproved = op.improved;
      }
      expect(previousInspected, greaterThan(0));
      expect(previousExpanded, greaterThan(0));
    });

    test('start equals goal returns exactly one point', () {
      const PathTask task = PathTask(
        id: 'same',
        field: <String>['..', '..'],
        start: GridPoint(x: 1, y: 1),
        end: GridPoint(x: 1, y: 1),
      );
      final AStarTraceResult trace = solver.trace(task);
      expect(trace.path, hasLength(1));
      expect(trace.path.single.x, 1);
      expect(trace.path.single.y, 1);
      expect(trace.totalComputations, 1);
    });

    test('rejects a blocked start and malformed fields', () {
      const PathTask blocked = PathTask(
        id: 'blocked',
        field: <String>['X.', '..'],
        start: GridPoint(x: 0, y: 0),
        end: GridPoint(x: 1, y: 1),
      );
      expect(() => solver.trace(blocked), throwsArgumentError);

      const PathTask malformed = PathTask(
        id: 'malformed',
        field: <String>['...', '..'],
        start: GridPoint(x: 0, y: 0),
        end: GridPoint(x: 1, y: 1),
      );
      expect(() => solver.trace(malformed), throwsFormatException);
    });

    test('throws when the goal is unreachable', () {
      const PathTask task = PathTask(
        id: 'unreachable',
        field: <String>['.XX', 'XXX', 'XX.'],
        start: GridPoint(x: 0, y: 0),
        end: GridPoint(x: 2, y: 2),
      );
      expect(() => solver.trace(task), throwsStateError);
    });

    test('matches an independent BFS oracle on a matrix with obstacles', () {
      const List<String> field = <String>[
        '......',
        '.XXX..',
        '..X...',
        '......',
        '.XX...',
        '......',
      ];
      for (final (int startX, int startY, int endX, int endY)
          in <(int, int, int, int)>[
            (0, 0, 5, 5),
            (0, 5, 5, 0),
            (3, 3, 5, 1),
          ]) {
        final PathTask task = PathTask(
          id: '$startX-$startY',
          field: field,
          start: GridPoint(x: startX, y: startY),
          end: GridPoint(x: endX, y: endY),
        );
        final int expected = _oracleShortestMoves(task);
        final AStarTraceResult trace = solver.trace(task);
        _checkRoute(task, trace.path);
        expect(trace.path.length - 1, expected);
      }
    });
  });
}

void _checkRoute(PathTask task, List<GridPoint> path) {
  expect(path, isNotEmpty);
  expect((path.first.x, path.first.y), (task.start.x, task.start.y));
  expect((path.last.x, path.last.y), (task.end.x, task.end.y));
  for (int i = 0; i < path.length; i++) {
    final GridPoint step = path[i];
    expect(task.field[step.y][step.x], '.');
    if (i == 0) continue;
    final GridPoint prior = path[i - 1];
    final int dx = (step.x - prior.x).abs();
    final int dy = (step.y - prior.y).abs();
    expect(math.max(dx, dy), 1, reason: 'Non-adjacent step: $i');
  }
}

/// Independent breadth-first oracle, deliberately separate from A* source.
int _oracleShortestMoves(PathTask task) {
  final int size = task.field.length;
  final Queue<(int, int, int)> queue = Queue<(int, int, int)>()
    ..add((task.start.x, task.start.y, 0));
  final Set<(int, int)> visited = <(int, int)>{(task.start.x, task.start.y)};
  while (queue.isNotEmpty) {
    final (int x, int y, int distance) = queue.removeFirst();
    if (x == task.end.x && y == task.end.y) return distance;
    for (int dy = -1; dy <= 1; dy++) {
      for (int dx = -1; dx <= 1; dx++) {
        if (dx == 0 && dy == 0) continue;
        final int nx = x + dx;
        final int ny = y + dy;
        if (nx < 0 || ny < 0 || nx >= size || ny >= size) continue;
        if (task.field[ny][nx] == 'X' || !visited.add((nx, ny))) continue;
        queue.add((nx, ny, distance + 1));
      }
    }
  }
  throw StateError('Unreachable in oracle');
}
