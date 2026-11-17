import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class ProxyInterceptor extends Interceptor {
  const new();

  static const bool _enabled = bool.fromEnvironment('USE_API_PROXY');

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (!kIsWeb || !_enabled) {
      handler.next(options);
      return;
    }

    // Dio has already combined the base URL, endpoint path,
    // and request query parameters at this point.
    final Uri target = options.uri;

    if (target.scheme != 'http' && target.scheme != 'https') {
      handler.next(options);
      return;
    }

    // Don't proxy requests to this application itself.
    if (target.origin == Uri.base.origin) {
      handler.next(options);
      return;
    }

    options.baseUrl = Uri.base.origin;
    options.path = '/api/proxy';

    // Keep the original URL and all its query parameters.
    options.queryParameters = <String, dynamic>{'url': target.toString()};

    // Request method, body and headers remain unchanged.
    handler.next(options);
  }
}
