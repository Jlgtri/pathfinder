import 'dart:collection';
import 'dart:math' show max;

import 'api.dart';

part 'solvers/a_star_trace.dart';

abstract interface class ShortestPathSolver {
  Future<List<GridPoint>> solve(PathTask task);
}
