import 'package:flutter/material.dart';

import '../core/async/loadable.dart';
import '../core/theme/app_theme.dart';
import '../data/api/api_exception.dart';
import '../data/session.dart';
import 'kw_button.dart';
import 'kw_common.dart';

/// Renders a [Loadable] as skeleton → data → error, cross-fading between them
/// so a slow endpoint doesn't make the screen flicker.
class AsyncView<T> extends StatelessWidget {
  const AsyncView({
    super.key,
    required this.state,
    required this.builder,
    this.loading,
    this.onRetry,
    this.emptyCheck,
    this.empty,
  });

  final Loadable<T> state;
  final Widget Function(BuildContext context, T value) builder;

  /// Skeleton for the first load. Defaults to a centred spinner.
  final Widget? loading;
  final VoidCallback? onRetry;

  /// Lets a caller treat "loaded but no rows" as an empty state.
  final bool Function(T value)? emptyCheck;
  final Widget? empty;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final Widget child;

        if (state.isInitialLoad) {
          child = KeyedSubtree(
            key: const ValueKey('async-loading'),
            child: loading ?? const _CenteredSpinner(),
          );
        } else if (state.error != null && !state.hasValue) {
          child = KeyedSubtree(
            key: const ValueKey('async-error'),
            child: ApiErrorState(
              error: state.error!,
              onRetry: onRetry ?? () => state.load(),
            ),
          );
        } else if (state.hasValue) {
          final value = state.value as T;
          final isEmpty = emptyCheck?.call(value) ?? false;
          child = KeyedSubtree(
            key: ValueKey(isEmpty ? 'async-empty' : 'async-data'),
            child: isEmpty
                ? (empty ?? const SizedBox.shrink())
                : builder(context, value),
          );
        } else {
          child = const KeyedSubtree(
            key: ValueKey('async-idle'),
            child: SizedBox.shrink(),
          );
        }

        return AnimatedSwitcher(
          duration: Motion.normal,
          switchInCurve: Motion.enter,
          switchOutCurve: Motion.exit,
          child: child,
        );
      },
    );
  }
}

class _CenteredSpinner extends StatelessWidget {
  const _CenteredSpinner();

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(40),
      child: SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(strokeWidth: 2.6),
      ),
    ),
  );
}

/// Failure state with a retry. Network and auth problems get their own
/// wording via [ApiException.userMessage].
class ApiErrorState extends StatelessWidget {
  const ApiErrorState({super.key, required this.error, this.onRetry});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final api = error is ApiException ? error as ApiException : null;
    final offline = api?.kind == ApiErrorKind.network;

    return KwEmptyState(
      icon: offline ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
      title: offline ? s.errorOffline : s.errorGeneric,
      message: api?.userMessageIn(s) ?? s.errorTryAgain,
      action: onRetry == null
          ? null
          : SizedBox(
              width: 180,
              child: KwButton(
                label: s.retry,
                icon: Icons.refresh_rounded,
                size: KwButtonSize.small,
                onPressed: onRetry,
              ),
            ),
    );
  }
}

/// Turns any thrown object into a one-line message for a snackbar, in the
/// language the session is currently set to.
String describeError(BuildContext context, Object error) {
  final s = context.s;
  return error is ApiException ? error.userMessageIn(s) : s.errorGenericFull;
}
