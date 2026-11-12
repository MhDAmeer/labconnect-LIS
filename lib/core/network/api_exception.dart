/// The different ways a call can fail, in terms the UI cares about.
enum ApiErrorKind {
  /// No connection, DNS failure, TLS failure or timeout.
  network,

  /// 400 - something wrong with what we sent.
  badRequest,

  /// 401 - not logged in / session over.
  unauthorized,

  /// 403 - the role (or facility) doesn't allow this.
  forbidden,

  /// 404 - missing, or belongs to a facility the user can't see.
  notFound,

  /// 5xx.
  server,

  /// Anything else, including a reply we couldn't understand.
  unknown,
}

class ApiException implements Exception {
  const ApiException(this.kind, this.message, {this.statusCode});

  final ApiErrorKind kind;

  /// Text that is safe to show to the user as it is.
  final String message;
  final int? statusCode;

  bool get isForbidden => kind == ApiErrorKind.forbidden;
  bool get isNetwork => kind == ApiErrorKind.network;

  @override
  String toString() => 'ApiException($kind, $statusCode)';
}

/// Turns any thrown object into text for the screen.
String errorText(Object error) {
  if (error is ApiException) return error.message;
  return 'Something went wrong, try again';
}
