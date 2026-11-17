import 'dart:async';

import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'routes.dart';
import 'solvers.dart';
import 'styles.dart';

part 'providers.g.dart';
part 'providers/preferences/endpoint_url.dart';
part 'providers/preferences/theme.dart';
part 'providers/processing.dart';

/// The provider of the [Dio] client.
@Riverpod(keepAlive: true)
Dio dio(Ref ref) => throw UnimplementedError();

/// The provider of the [API].
@Riverpod(keepAlive: true, dependencies: <Object>[dio, EndpointUrlNotifier])
Future<API?> api(Ref ref) async {
  final Uri? uri = await ref.watch(endpointUrlProvider.future);
  if (uri == null) {
    return null;
  }

  // Retrofit's configured base URL must use the actual user endpoint.
  // A globally overridden API(dio, baseUrl: Config.apiUrl) is static.
  String url = uri.replace().toString();
  if (kDebugMode &&
      kIsWeb &&
      url == 'https://flutter.webspark.dev/flutter/api') {
    url = '${Uri.base.origin}/webspark/flutter/api';
  }

  return API(ref.read(dioProvider), baseUrl: url);
}

@Riverpod(keepAlive: true)
SharedPreferencesAsync preferences(Ref ref) => throw UnimplementedError();

@Riverpod(keepAlive: true)
class CurrentRoute extends _$CurrentRoute {
  @override
  Routes<Object?> build() => Routes.splash;

  void seenSplash() => state = Routes.configuration;
}
