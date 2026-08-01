/// A failed API call, already translated into something a screen can show.
///
/// The backend answers errors with `{success:false, message, errors}`
/// (`App\Traits\ApiResponse::error`), and Laravel's validator adds a
/// field-keyed `errors` map on 422 — both are preserved here.
class ApiException implements Exception {
  const ApiException(
    this.message, {
    this.statusCode,
    this.fieldErrors = const {},
    this.kind = ApiErrorKind.server,
  });

  final String message;
  final int? statusCode;

  /// Laravel 422 shape: `{"phone": ["The phone field is required."]}`.
  final Map<String, List<String>> fieldErrors;
  final ApiErrorKind kind;

  bool get isUnauthorized => statusCode == 401;
  bool get isValidation => statusCode == 422;

  /// First validation message for [field], if the server flagged it.
  String? fieldError(String field) => fieldErrors[field]?.firstOrNull;

  /// Message safe to drop straight into a snackbar, in the app's Hinglish
  /// voice for the cases the backend can't phrase itself.
  String get userMessage => switch (kind) {
    ApiErrorKind.network =>
      'Internet nahi mil raha. Connection check karke dobara try karein.',
    ApiErrorKind.timeout => 'Server jawab nahi de raha. Dobara try karein.',
    ApiErrorKind.parse => 'Server se galat jawab aaya. Dobara try karein.',
    ApiErrorKind.unauthorized => 'Session khatam ho gaya. Dobara login karein.',
    ApiErrorKind.server => message,
  };

  @override
  String toString() => 'ApiException($statusCode, $kind): $message';
}

enum ApiErrorKind { network, timeout, parse, unauthorized, server }
