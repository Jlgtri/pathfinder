import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

/// The callback to return a function.
typedef GuardCallback = FutureOr<bool> Function() Function(
  FutureOr<void> Function() func,
);

/// Returns the callback to discard any simultaneous function calls.
GuardCallback useGuard() => use(const _GuardHook());

class _GuardHook extends Hook<GuardCallback> {
  const new();

  @override
  _GuardHookState createState() => _GuardHookState();
}

class _GuardHookState extends HookState<GuardCallback, _GuardHook> {
  bool _isLoading = false;

  @override
  GuardCallback build(BuildContext context) =>
      (FutureOr<void> Function() func) => () async {
        if (_isLoading) {
          return false;
        }

        _isLoading = true;
        try {
          await func();
          return true;
        } finally {
          _isLoading = false;
        }
      };

  @override
  String get debugLabel => 'useGuard';
}
