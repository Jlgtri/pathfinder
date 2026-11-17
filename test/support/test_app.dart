/// Test-only app harness. Uses production routes/providers and an in-memory Dio
/// interceptor. Nothing is sent to Webspark or any other external server.
library;

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../lib/src/providers.dart';
import '../../lib/src/routes.dart';
import '../../lib/src/styles.dart';

/// A full, deterministic two-task API fixture.
class FakeWebsparkBackend {
  new({this.failFirstGet = false, this.failFirstPost = false}) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest:
            (RequestOptions options, RequestInterceptorHandler handler) {
              requests.add(options);
              if (options.method.toUpperCase() == 'GET') {
                if (failFirstGet) {
                  failFirstGet = false;
                  handler.resolve(
                    Response<Map<String, dynamic>>(
                      requestOptions: options,
                      statusCode: 200,
                      data: <String, dynamic>{
                        'error': true,
                        'message': 'Simulated task fetch failure',
                        'data': <Object>[],
                      },
                    ),
                  );
                  return;
                }
                handler.resolve(
                  Response<Map<String, dynamic>>(
                    requestOptions: options,
                    statusCode: 200,
                    data: <String, dynamic>{
                      'error': false,
                      'message': 'OK',
                      'data': taskData,
                    },
                  ),
                );
                return;
              }

              if (options.method.toUpperCase() == 'POST') {
                lastPostedBody = options.data;
                if (failFirstPost) {
                  failFirstPost = false;
                  handler.resolve(
                    Response<Map<String, dynamic>>(
                      requestOptions: options,
                      statusCode: 200,
                      data: <String, dynamic>{
                        'error': true,
                        'message': 'Simulated submission failure',
                        'data': <Object>[],
                      },
                    ),
                  );
                  return;
                }
                handler.resolve(
                  Response<Map<String, dynamic>>(
                    requestOptions: options,
                    statusCode: 200,
                    data: <String, dynamic>{
                      'error': false,
                      'message': 'Saved',
                      'data': <Map<String, dynamic>>[
                        for (final Map<String, dynamic> task in taskData)
                          <String, dynamic>{'id': task['id'], 'correct': true},
                      ],
                    },
                  ),
                );
                return;
              }

              handler.reject(
                DioException(
                  requestOptions: options,
                  message: 'Unexpected method ${options.method}',
                ),
              );
            },
      ),
    );
  }

  bool failFirstGet;
  bool failFirstPost;
  final Dio dio = Dio(
    BaseOptions(baseUrl: 'https://fake.pathfinder.test/api'),
  );
  final List<RequestOptions> requests = <RequestOptions>[];
  Object? lastPostedBody;

  static final List<Map<String, dynamic>> taskData = <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 'demo-01',
      'field': <String>['...', '...', '...'],
      'start': <String, int>{'x': 0, 'y': 0},
      'end': <String, int>{'x': 2, 'y': 2},
    },
    <String, dynamic>{
      'id': 'demo-02',
      'field': <String>['....', '.XX.', '....', '....'],
      'start': <String, int>{'x': 0, 'y': 3},
      'end': <String, int>{'x': 3, 'y': 0},
    },
  ];

  int count(String method) => requests
      .where((RequestOptions request) => request.method == method)
      .length;
}

/// Eliminates the SharedPreferences plugin from integration tests.
class TestThemeNotifier extends ThemeNotifier {
  @override
  Future<Themes> build() async => Themes.light;

  @override
  Future<void> toggle() async {
    state = AsyncData<Themes>(
      state.requireValue == Themes.light ? Themes.dark : Themes.light,
    );
  }

  @override
  Future<void> set(Themes? theme) async {
    state = AsyncData<Themes>(theme ?? Themes.light);
  }
}

/// A valid endpoint is available immediately without native storage.
class TestEndpointUrlNotifier extends EndpointUrlNotifier {
  @override
  Future<Uri?> build() async => Uri.parse('https://fake.pathfinder.test/api');

  @override
  Future<void> set(Uri? uri) async {
    state = AsyncData<Uri?>(uri);
  }
}

List<Override> pathfinderTestOverrides(FakeWebsparkBackend backend) =>
    <Override>[
      dioProvider.overrideWithValue(backend.dio),
      themeProvider.overrideWith(TestThemeNotifier.new),
      endpointUrlProvider.overrideWith(TestEndpointUrlNotifier.new),
    ];

/// Create this before pumping so RoutesApp can synchronously read themeProvider
/// with `.requireValue` during its first build.
class TestPathfinderApp {
  new(FakeWebsparkBackend backend, {String initialLocation = '/configure'})
    : container = ProviderContainer(
        overrides: pathfinderTestOverrides(backend),
      ),
      router = GoRouter(
        navigatorKey: RoutesApp.navigatorKey,
        initialLocation: initialLocation,
        routes: Routes.routes,
      );

  final ProviderContainer container;
  final GoRouter router;

  Future<void> initialize() async {
    await container.read(themeProvider.future);
    await container.read(endpointUrlProvider.future);
  }

  Widget get widget => UncontrolledProviderScope(
    container: container,
    child: RoutesApp(router),
  );

  void dispose() {
    router.dispose();
    container.dispose();
  }
}
