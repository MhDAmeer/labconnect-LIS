import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'api_exception.dart';
import 'token_storage.dart';

/// A file answered by the server (the result report PDF).
class DownloadedFile {
  const DownloadedFile({required this.bytes, this.fileName});

  final Uint8List bytes;
  final String? fileName;
}

/// Thin wrapper around `http` that knows the LabConnect rules:
///
///  * every logged-in call sends the Bearer access token,
///  * a 401 triggers exactly one token refresh and one retry of the call,
///  * the success envelope `{success, message, data, errors}` is unwrapped,
///  * both error body shapes (`detail` / envelope) end up as [ApiException].
class ApiClient {
  ApiClient({required TokenStorage tokens, http.Client? httpClient})
      : _tokens = tokens,
        _http = httpClient ?? http.Client();

  final TokenStorage _tokens;
  final http.Client _http;

  /// Called when the refresh token is rejected - the session is over and the
  /// app must go back to Login.
  void Function()? onSessionExpired;

  /// Shared by every call that hits a 401 at the same moment, so the refresh
  /// token (which rotates) is only ever spent once.
  Future<bool>? _refreshInFlight;

  // ---------------------------------------------------------------------------
  // Public helpers
  // ---------------------------------------------------------------------------

  Future<dynamic> get(
    String path, {
    Map<String, String>? query,
    bool auth = true,
  }) async {
    final uri = _uri(path, query);
    final response = await _send('GET', uri, auth: auth);
    return _unwrap(response, path: uri.path);
  }

  Future<dynamic> post(
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
    bool showServerMessage = false,
  }) async {
    final uri = _uri(path, null);
    final response = await _send(
      'POST',
      uri,
      auth: auth,
      body: body,
    );
    return _unwrap(
      response,
      showServerMessage: showServerMessage,
      path: uri.path,
    );
  }

  /// Reads a list endpoint and follows `next` until it is null.
  ///
  /// Works for both shapes the API uses: a paged object
  /// `{count, next, previous, results}` and a plain list.
  Future<List<dynamic>> getAllPages(
    String path, {
    Map<String, String>? query,
  }) async {
    final items = <dynamic>[];
    final params = <String, String>{
      'page_size': '${AppConfig.maxPageSize}',
      ...?query,
    };
    Uri? uri = _uri(path, params);

    for (var page = 0;
        page < AppConfig.maxPagesPerList && uri != null;
        page++) {
      final currentUri = uri;
      final data = _unwrap(
        await _send('GET', currentUri),
        path: currentUri.path,
      );
      if (data is List) {
        items.addAll(data);
        break;
      }
      if (data is Map<String, dynamic>) {
        final results = data['results'];
        if (results is List) items.addAll(results);
        final next = data['next'];
        uri = next is String && next.isNotEmpty ? _rebase(next) : null;
      } else {
        break;
      }
    }
    return items;
  }

  /// Fetches a binary reply (the PDF report).
  Future<DownloadedFile> getFile(
    String path, {
    Map<String, String>? query,
  }) async {
    final uri = _uri(path, query);
    final response = await _send('GET', uri, accept: '*/*');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _errorFrom(response, path: uri.path);
    }
    return DownloadedFile(
      bytes: response.bodyBytes,
      fileName: _fileNameFrom(response.headers['content-disposition']),
    );
  }

  void close() => _http.close();

  // ---------------------------------------------------------------------------
  // Request plumbing
  // ---------------------------------------------------------------------------

  Uri _uri(String path, Map<String, String>? query) {
    final base = Uri.parse(AppConfig.apiBase);
    final cleanQuery = query == null
        ? null
        : (Map<String, String>.of(query)
          ..removeWhere((_, value) => value.isEmpty));
    return base.replace(
      path: '${AppConfig.apiPrefix}$path',
      queryParameters:
          (cleanQuery == null || cleanQuery.isEmpty) ? null : cleanQuery,
    );
  }

  /// `next` links are absolute. We keep only the path and query and build the
  /// address from our own base, so the token can never be sent to another
  /// host (or over plain http) because of what a response says.
  Uri _rebase(String next) {
    final parsed = Uri.parse(next);
    final base = Uri.parse(AppConfig.apiBase);
    return base.replace(
      path: parsed.path,
      queryParameters:
          parsed.queryParameters.isEmpty ? null : parsed.queryParameters,
    );
  }

  Future<http.Response> _send(
    String method,
    Uri uri, {
    bool auth = true,
    Object? body,
    String accept = 'application/json',
    bool canRetry = true,
  }) async {
    final headers = <String, String>{'Accept': accept};
    if (body != null) headers['Content-Type'] = 'application/json';

    if (auth) {
      final access = await _tokens.readAccess();
      if (access != null && access.isNotEmpty) {
        headers['Authorization'] = 'Bearer $access';
      }
    }

    final response = await _dispatch(method, uri, headers, body);

    if (response.statusCode == 401 && auth && canRetry) {
      final refreshed = await _refreshAccessToken();
      if (refreshed) {
        return _send(
          method,
          uri,
          auth: auth,
          body: body,
          accept: accept,
          canRetry: false,
        );
      }
      await _endSession();
      throw const ApiException(
        ApiErrorKind.unauthorized,
        'Your session has expired. Please sign in again.',
        statusCode: 401,
      );
    }
    return response;
  }

  Future<http.Response> _dispatch(
    String method,
    Uri uri,
    Map<String, String> headers,
    Object? body,
  ) async {
    try {
      final Future<http.Response> call;
      if (method == 'POST') {
        call = _http.post(uri, headers: headers, body: jsonEncode(body ?? {}));
      } else {
        call = _http.get(uri, headers: headers);
      }
      return await call.timeout(AppConfig.requestTimeout);
    } on TimeoutException {
      throw const ApiException(
        ApiErrorKind.network,
        'The server took too long to answer. Check your connection and try again.',
      );
    } on SocketException {
      throw const ApiException(
        ApiErrorKind.network,
        'No internet connection. Check your connection and try again.',
      );
    } on HandshakeException {
      throw const ApiException(
        ApiErrorKind.network,
        'Could not make a secure connection to the server.',
      );
    } on http.ClientException {
      throw const ApiException(
        ApiErrorKind.network,
        'Could not reach the server. Try again in a moment.',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Token refresh
  // ---------------------------------------------------------------------------

  Future<bool> _refreshAccessToken() {
    return _refreshInFlight ??=
        _doRefresh().whenComplete(() => _refreshInFlight = null);
  }

  /// Returns true when a new pair of tokens was saved, false when the server
  /// refused the refresh token. Network problems are thrown, so a bad
  /// connection never logs the user out.
  Future<bool> _doRefresh() async {
    final refresh = await _tokens.readRefresh();
    if (refresh == null || refresh.isEmpty) return false;

    final uri = _uri('/auth/refresh/', null);
    final response = await _dispatch(
      'POST',
      uri,
      const {'Accept': 'application/json', 'Content-Type': 'application/json'},
      {'refresh': refresh},
    );

    if (response.statusCode == 401 || response.statusCode == 400) return false;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _errorFrom(response, path: uri.path);
    }

    final data = _unwrap(response, path: uri.path);
    if (data is! Map<String, dynamic>) return false;
    final access = data['access'];
    final newRefresh = data['refresh'];
    if (access is! String || newRefresh is! String) return false;

    // The old refresh token is dead now - the new one must be saved.
    await _tokens.save(access: access, refresh: newRefresh);
    return true;
  }

  Future<void> _endSession() async {
    await _tokens.clear();
    onSessionExpired?.call();
  }

  // ---------------------------------------------------------------------------
  // Reading replies
  // ---------------------------------------------------------------------------

  dynamic _unwrap(
    http.Response response, {
    bool showServerMessage = false,
    String? path,
  }) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _errorFrom(
        response,
        showServerMessage: showServerMessage,
        path: path,
      );
    }
    if (response.bodyBytes.isEmpty) return null;

    final dynamic decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw const ApiException(
        ApiErrorKind.unknown,
        'Something went wrong, try again',
      );
    }

    if (decoded is Map<String, dynamic> && decoded.containsKey('success')) {
      if (decoded['success'] == false) {
        throw ApiException(
          ApiErrorKind.badRequest,
          _messageFrom(decoded) ?? 'Something went wrong, try again',
          statusCode: response.statusCode,
        );
      }
      return decoded['data'];
    }
    return decoded;
  }

  ApiException _errorFrom(
    http.Response response, {
    bool showServerMessage = false,
    String? path,
  }) {
    final code = response.statusCode;
    final serverMessage = _messageFromBody(response);

    if (code == 400) {
      return ApiException(
        ApiErrorKind.badRequest,
        serverMessage ?? 'Please check the details and try again.',
        statusCode: code,
      );
    }
    if (code == 401) {
      return ApiException(
        ApiErrorKind.unauthorized,
        serverMessage ?? 'Invalid username, password or lab code.',
        statusCode: code,
      );
    }
    if (code == 403) {
      // On login a 403/429 can be an account lock - the guide wants the
      // server's own words there.
      return ApiException(
        ApiErrorKind.forbidden,
        showServerMessage && serverMessage != null
            ? serverMessage
            : "You don't have access to this",
        statusCode: code,
      );
    }
    if (code == 404) {
      final message = serverMessage;
      final location = path == null ? '' : ' at $path';
      return ApiException(
        ApiErrorKind.notFound,
        message == null || message.toLowerCase() == 'not found'
            ? 'Not found$location (HTTP 404)'
            : '$message$location (HTTP 404)',
        statusCode: code,
      );
    }
    if (code == 429) {
      return ApiException(
        ApiErrorKind.badRequest,
        serverMessage ?? 'Too many attempts. Please wait a moment and retry.',
        statusCode: code,
      );
    }
    if (code >= 500) {
      return ApiException(
        ApiErrorKind.server,
        'Something went wrong, try again',
        statusCode: code,
      );
    }
    return ApiException(
      ApiErrorKind.unknown,
      serverMessage ?? 'Something went wrong, try again',
      statusCode: code,
    );
  }

  String? _messageFromBody(http.Response response) {
    if (response.bodyBytes.isEmpty) return null;
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      return _messageFrom(decoded);
    } catch (_) {
      return null;
    }
  }

  /// Handles `{"detail": "..."}` and the envelope `{"success": false,
  /// "message": "...", "errors": [...]}`. Field errors are used when the
  /// message itself is empty.
  String? _messageFrom(dynamic body) {
    if (body is! Map) return null;

    final detail = body['detail'];
    if (detail is String && detail.trim().isNotEmpty) return detail.trim();

    final message = body['message'];
    if (message is String && message.trim().isNotEmpty) return message.trim();

    final errors = body['errors'];
    if (errors is List && errors.isNotEmpty) {
      final first = errors.first;
      if (first is String && first.trim().isNotEmpty) return first.trim();
      if (first is Map) {
        final text = first['message'] ?? first['detail'];
        if (text is String && text.trim().isNotEmpty) return text.trim();
      }
    }
    if (errors is Map && errors.isNotEmpty) {
      final first = errors.values.first;
      if (first is List && first.isNotEmpty) return '${first.first}';
      if (first is String) return first;
    }
    return null;
  }

  String? _fileNameFrom(String? contentDisposition) {
    if (contentDisposition == null) return null;
    final match = RegExp(r'filename\*?=(?:UTF-8\x27\x27)?"?([^";]+)"?',
            caseSensitive: false)
        .firstMatch(contentDisposition);
    final raw = match?.group(1);
    if (raw == null || raw.isEmpty) return null;
    String decoded;
    try {
      decoded = Uri.decodeComponent(raw);
    } on ArgumentError {
      decoded = raw;
    }
    // Keep only the file name - never let the server pick a folder.
    return decoded.split(RegExp(r'[\\/]')).last;
  }
}
