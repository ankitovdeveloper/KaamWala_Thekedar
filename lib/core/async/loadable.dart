import 'package:flutter/foundation.dart';

/// One remote value plus its loading and error state.
///
/// Screens own a [Loadable] per endpoint, call [load] in `initState`, and
/// rebuild through a `ListenableBuilder`. Small enough to not need a state
/// management package, explicit enough to keep refresh semantics obvious.
class Loadable<T> extends ChangeNotifier {
  Loadable(this._fetch);

  Future<T> Function() _fetch;

  T? _value;
  Object? _error;
  bool _loading = false;
  bool _disposed = false;

  T? get value => _value;
  Object? get error => _error;
  bool get isLoading => _loading;
  bool get hasValue => _value != null;

  /// True only for the very first load — later refreshes keep showing the old
  /// data instead of flashing a skeleton.
  bool get isInitialLoad => _loading && _value == null;

  /// Swap the fetcher when its inputs change (a new filter, a new tab) and
  /// reload. Keeps the previous value on screen while the new one arrives.
  Future<void> refetchWith(Future<T> Function() fetch, {bool silent = true}) {
    _fetch = fetch;
    return load(silent: silent);
  }

  /// [silent] keeps any existing value visible while reloading — used by
  /// pull-to-refresh and filter changes.
  Future<void> load({bool silent = false}) async {
    if (_disposed) return;

    _loading = true;
    _error = null;
    if (!silent) _value = null;
    notifyListeners();

    try {
      final result = await _fetch();
      if (_disposed) return;
      _value = result;
      _error = null;
    } on Object catch (e) {
      if (_disposed) return;
      _error = e;
      if (!silent) _value = null;
    } finally {
      if (!_disposed) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  /// Applies a local change without a round trip — used for optimistic updates
  /// where the server has already confirmed the write.
  void setValue(T value) {
    if (_disposed) return;
    _value = value;
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
