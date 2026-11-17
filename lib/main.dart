import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talker/talker.dart';
import 'package:talker_dio_logger/talker_dio_logger.dart';
import 'package:talker_riverpod_logger/talker_riverpod_logger.dart';

// import 'src/generated/env.g.dart';
import 'src/providers.dart';
import 'src/routes.dart';
import 'src/utils/proxy_interceptor.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: WidgetsBinding.instance);

  final Talker talker = Talker();
  final Dio dio = Dio(BaseOptions())
    ..interceptors.add(const ProxyInterceptor())
    ..interceptors.add(
      TalkerDioLogger(
        talker: talker,
        settings: const TalkerDioLoggerSettings(
          printRequestHeaders: true,
          printResponseHeaders: true,
        ),
      ),
    );

  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[
      dioProvider.overrideWithValue(dio),
      preferencesProvider.overrideWithValue(SharedPreferencesAsync()),
    ],
    observers: <ProviderObserver>[
      TalkerRiverpodObserver(
        talker: talker,
        settings: const TalkerRiverpodLoggerSettings(
          printProviderDisposed: true,
        ),
      ),
    ],
  );

  await Future.wait(<Future<Object?>>[container.read(themeProvider.future)]);

  final GoRouter router = GoRouter(
    initialLocation: container.read(currentRouteProvider).location,
    observers: <NavigatorObserver>[],
    routes: Routes.routes,
  );

  runApp(
    UncontrolledProviderScope(container: container, child: RoutesApp(router)),
  );

  WidgetsBinding.instance.addPostFrameCallback(
    (_) => FlutterNativeSplash.remove(),
  );

  await Future.wait(<Future<Object?>>[
    if (!kIsWeb) ...<Future<Object?>>[
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge),
      SystemChrome.setPreferredOrientations(<DeviceOrientation>[
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]),
    ],
  ]);
}
