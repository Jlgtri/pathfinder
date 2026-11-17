part of '../api.dart';

mixin $PathFinding {
  @GET('')
  Future<PathTasksResponse> getTasks();

  @POST('')
  Future<SubmitResultsResponse> sendResults(
    @Body() List<PathResultRequest> results,
    @Queries() Map<String, Object?> queries,
  );
}

@MappableClass()
class PathTasksResponse with PathTasksResponseMappable {
  const new({required this.error, required this.message, required this.data});

  final bool error;
  final String message;
  final List<PathTask> data;
}

@MappableClass()
class PathTask with PathTaskMappable {
  const new({
    required this.id,
    required this.field,
    required this.start,
    required this.end,
  });

  final String id;

  /// Rows of the grid: '.' = empty, 'X' = blocked.
  final List<String> field;

  final GridPoint start;
  final GridPoint end;
}

@MappableClass()
class GridPoint with GridPointMappable {
  const new({required this.x, required this.y});

  final int x;
  final int y;
}

@MappableClass()
class PathResultRequest with PathResultRequestMappable {
  const new({required this.id, required this.result});

  final String id;
  final PathResultData result;
}

@MappableClass()
class PathResultData with PathResultDataMappable {
  const new({required this.steps, required this.path});

  /// Ordered coordinates from start to end.
  final List<GridPoint> steps;

  /// Example: (0,3)->(1,2)->(2,1)->(3,0)
  final String path;
}

@MappableClass()
class SubmitResultsResponse with SubmitResultsResponseMappable {
  const new({required this.error, required this.message, required this.data});

  final bool error;
  final String message;
  final List<PathVerification> data;
}

@MappableClass()
class PathVerification with PathVerificationMappable {
  const new({required this.id, required this.correct});

  final String id;
  final bool correct;
}
