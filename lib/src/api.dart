import 'package:dart_mappable/dart_mappable.dart';
import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart' hide Field;

part 'api.g.dart';
part 'api.mapper.dart';
part 'api/pathfinding.dart';

@RestApi(parser: Parser.DartMappable)
abstract class API with $PathFinding {
  factory(Dio dio, {String? baseUrl}) = _API;
}
