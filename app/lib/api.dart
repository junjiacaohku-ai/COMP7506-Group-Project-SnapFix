import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'models.dart';

const kApiBaseUrl = 'http://127.0.0.1:8001';

class ApiException implements Exception {
  const ApiException(
    this.message, {
    this.statusCode,
    this.isTimeout = false,
    this.isCancelled = false,
  });

  final String message;
  final int? statusCode;
  final bool isTimeout;
  final bool isCancelled;

  bool get isQualityError => statusCode == 422;

  @override
  String toString() => message;
}

class DiagnosisCancellation {
  final Completer<void> _completer = Completer<void>();

  bool get isCancelled => _completer.isCompleted;
  Future<void> get whenCancelled => _completer.future;

  void cancel() {
    if (!_completer.isCompleted) _completer.complete();
  }
}

class ApiClient {
  ApiClient({
    http.Client? client,
    this.baseUrl = kApiBaseUrl,
    this.diagnosisTimeout = const Duration(seconds: 120),
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final String baseUrl;
  final Duration diagnosisTimeout;
  String languageCode = 'en';
  String? _accessToken;
  void Function()? onUnauthorized;
  void Function(Session session)? onDiagnosisCompleted;

  bool get hasAccessToken => _accessToken != null;

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  void setAccessToken(String? token) {
    _accessToken = token;
  }

  Map<String, String> get _authHeaders => {
    if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
  };

  Map<String, String> get _jsonHeaders => {
    'Content-Type': 'application/json',
    ..._authHeaders,
  };

  Future<HealthInfo> health() async {
    final json = await _send(() => _client.get(_uri('/api/health')));
    return HealthInfo.fromJson(json as Map<String, dynamic>);
  }

  Future<AuthResult> register(
    String name,
    String email,
    String password,
  ) async {
    final json = await _send(
      () => _client.post(
        _uri('/api/auth/register'),
        headers: _jsonHeaders,
        body: jsonEncode({'name': name, 'email': email, 'password': password}),
      ),
    );
    return AuthResult.fromJson(json as Map<String, dynamic>);
  }

  Future<AuthResult> login(String email, String password) async {
    final json = await _send(
      () => _client.post(
        _uri('/api/auth/login'),
        headers: _jsonHeaders,
        body: jsonEncode({'email': email, 'password': password}),
      ),
    );
    return AuthResult.fromJson(json as Map<String, dynamic>);
  }

  Future<String> appleNonce() async {
    final json = await _send(
      () => _client.post(_uri('/api/auth/apple/nonce'), headers: _jsonHeaders),
    );
    return (json as Map<String, dynamic>)['nonce'] as String;
  }

  Future<AuthResult> loginWithApple(
    String identityToken,
    String nonce,
    String? name,
  ) async {
    final json = await _send(
      () => _client.post(
        _uri('/api/auth/apple'),
        headers: _jsonHeaders,
        body: jsonEncode({
          'identity_token': identityToken,
          'nonce': nonce,
          'name': name,
        }),
      ),
    );
    return AuthResult.fromJson(json as Map<String, dynamic>);
  }

  Future<AuthResult> loginWithGoogle(String identityToken) async {
    final json = await _send(
      () => _client.post(
        _uri('/api/auth/google'),
        headers: _jsonHeaders,
        body: jsonEncode({'identity_token': identityToken}),
      ),
    );
    return AuthResult.fromJson(json as Map<String, dynamic>);
  }

  Future<AuthUser> me() async {
    final json = await _send(
      () => _client.get(_uri('/api/auth/me'), headers: _authHeaders),
    );
    return AuthUser.fromJson(
      (json as Map<String, dynamic>)['user'] as Map<String, dynamic>,
    );
  }

  Future<AuthUser> updateName(String name) async {
    final json = await _send(
      () => _client.patch(
        _uri('/api/auth/me'),
        headers: _jsonHeaders,
        body: jsonEncode({'name': name}),
      ),
    );
    return AuthUser.fromJson(
      (json as Map<String, dynamic>)['user'] as Map<String, dynamic>,
    );
  }

  Future<List<LoginIdentity>> listIdentities() async {
    final json = await _send(
      () => _client.get(_uri('/api/auth/identities'), headers: _authHeaders),
    );
    return [
      for (final item in (json as Map<String, dynamic>)['identities'] as List)
        LoginIdentity.fromJson(item as Map<String, dynamic>),
    ];
  }

  Future<AuthUser> linkApple(
    String identityToken,
    String nonce,
    String? name,
  ) async {
    final json = await _send(
      () => _client.post(
        _uri('/api/auth/apple/link'),
        headers: _jsonHeaders,
        body: jsonEncode({
          'identity_token': identityToken,
          'nonce': nonce,
          'name': name,
        }),
      ),
    );
    return AuthUser.fromJson(
      (json as Map<String, dynamic>)['user'] as Map<String, dynamic>,
    );
  }

  Future<AuthUser> linkGoogle(String identityToken) async {
    final json = await _send(
      () => _client.post(
        _uri('/api/auth/google/link'),
        headers: _jsonHeaders,
        body: jsonEncode({'identity_token': identityToken}),
      ),
    );
    return AuthUser.fromJson(
      (json as Map<String, dynamic>)['user'] as Map<String, dynamic>,
    );
  }

  Future<void> unlinkIdentity(String provider) async {
    await _send(
      () => _client.delete(
        _uri('/api/auth/identities/$provider'),
        headers: _authHeaders,
      ),
    );
  }

  Future<int> changePassword(
    String? currentPassword,
    String newPassword,
  ) async {
    final json = await _send(
      () => _client.post(
        _uri('/api/auth/password'),
        headers: _jsonHeaders,
        body: jsonEncode({
          'current_password': currentPassword,
          'new_password': newPassword,
        }),
      ),
    );
    return (json as Map<String, dynamic>)['revoked_devices'] as int? ?? 0;
  }

  Future<void> deleteAccount() async {
    await _send(
      () => _client.delete(
        _uri('/api/auth/me'),
        headers: _jsonHeaders,
        body: jsonEncode({'confirmation': 'DELETE'}),
      ),
    );
  }

  Future<Map<String, String>> getPreferences() async {
    final json = await _send(
      () => _client.get(_uri('/api/preferences'), headers: _authHeaders),
    );
    final values = (json as Map<String, dynamic>)['values'] as Map;
    return values.map((key, value) => MapEntry('$key', '$value'));
  }

  Future<void> updatePreference(String key, String value) async {
    await _send(
      () => _client.put(
        _uri('/api/preferences'),
        headers: _jsonHeaders,
        body: jsonEncode({
          'values': {key: value},
        }),
      ),
    );
  }

  Future<List<ManualInfo>> manuals() async {
    final json = await _send(() => _client.get(_uri('/api/manuals')));
    return [
      for (final item in json as List)
        ManualInfo.fromJson(item as Map<String, dynamic>),
    ];
  }

  Future<void> logout() async {
    await _send(
      () => _client.post(_uri('/api/auth/logout'), headers: _authHeaders),
    );
  }

  Future<void> submitDiagnosisFeedback({
    required String event,
    required String language,
    required int elapsedSeconds,
    String? error,
    String? platform,
  }) async {
    await _send(
      () => _client.post(
        _uri('/api/diagnosis-feedback'),
        headers: _jsonHeaders,
        body: jsonEncode({
          'event': event,
          'language': language,
          'elapsed_seconds': elapsedSeconds,
          'error': error ?? '',
          'platform': platform ?? '',
        }),
      ),
    );
  }

  Future<Session> analyzeImage(
    String filePath, {
    DiagnosisCancellation? cancellation,
  }) async {
    final abort = Completer<void>();
    final request =
        http.AbortableMultipartRequest(
            'POST',
            _uri('/api/analyze/image'),
            abortTrigger: abort.future,
          )
          ..headers.addAll(_authHeaders)
          ..fields['language'] = languageCode
          ..files.add(await http.MultipartFile.fromPath('file', filePath));
    final json = await _sendAnalysis(request, abort, cancellation);
    final session = Session.fromJson(json as Map<String, dynamic>);
    onDiagnosisCompleted?.call(session);
    return session;
  }

  Future<Session> diagnoseManual(
    String brand,
    String errorCode, {
    DiagnosisCancellation? cancellation,
  }) async {
    final abort = Completer<void>();
    final request =
        http.AbortableRequest(
            'POST',
            _uri('/api/diagnose/manual'),
            abortTrigger: abort.future,
          )
          ..headers.addAll(_jsonHeaders)
          ..body = jsonEncode({
            'brand': brand,
            'error_code': errorCode,
            'language': languageCode,
          });
    final json = await _sendAnalysis(request, abort, cancellation);
    return Session.fromJson(json as Map<String, dynamic>);
  }

  Future<dynamic> _sendAnalysis(
    http.Abortable request,
    Completer<void> abort,
    DiagnosisCancellation? cancellation,
  ) async {
    var timedOut = false;
    final timer = Timer(diagnosisTimeout, () {
      timedOut = true;
      if (!abort.isCompleted) abort.complete();
    });
    unawaited(
      cancellation?.whenCancelled.then((_) {
            if (!abort.isCompleted) abort.complete();
          }) ??
          Future<void>.value(),
    );
    try {
      final operation = () async {
        final streamed = await _client.send(request);
        final body = await streamed.stream.bytesToString();
        return _decode(streamed.statusCode, body);
      }();
      return await operation.timeout(diagnosisTimeout);
    } on http.RequestAbortedException {
      if (cancellation?.isCancelled ?? false) {
        throw const ApiException('分析已取消', isCancelled: true);
      }
      if (timedOut) {
        throw const ApiException('分析超时，请稍后重试', isTimeout: true);
      }
      throw const ApiException('无法连接后端服务');
    } on TimeoutException {
      if (!abort.isCompleted) abort.complete();
      throw const ApiException('分析超时，请稍后重试', isTimeout: true);
    } on SocketException {
      throw const ApiException('无法连接后端服务');
    } on http.ClientException {
      if (cancellation?.isCancelled ?? false) {
        throw const ApiException('分析已取消', isCancelled: true);
      }
      throw const ApiException('无法连接后端服务');
    } finally {
      timer.cancel();
    }
  }

  Future<List<DiagnosisFeedback>> listDiagnosisFeedback() async {
    final json = await _send(
      () => _client.get(_uri('/api/diagnosis-feedback'), headers: _authHeaders),
    );
    return [
      for (final item in json as List)
        DiagnosisFeedback.fromJson(item as Map<String, dynamic>),
    ];
  }

  Future<List<Session>> listSessions() async {
    final json = await _send(
      () => _client.get(_uri('/api/sessions'), headers: _authHeaders),
    );
    return [
      for (final s in json as List) Session.fromJson(s as Map<String, dynamic>),
    ];
  }

  Future<Session> getSession(String id) async {
    final json = await _send(
      () => _client.get(_uri('/api/sessions/$id'), headers: _authHeaders),
    );
    return Session.fromJson(json as Map<String, dynamic>);
  }

  Future<void> deleteSession(String id) async {
    await _send(
      () => _client.delete(_uri('/api/sessions/$id'), headers: _authHeaders),
    );
  }

  Future<Session> stepFeedback(
    String sessionId,
    String stepId,
    String feedback,
  ) async {
    final json = await _send(
      () => _client.post(
        _uri('/api/sessions/$sessionId/steps/$stepId/feedback'),
        headers: _jsonHeaders,
        body: jsonEncode({'feedback': feedback}),
      ),
    );
    return Session.fromJson(json as Map<String, dynamic>);
  }

  Future<Session> updateStatus(String sessionId, String status) async {
    final json = await _send(
      () => _client.post(
        _uri('/api/sessions/$sessionId/status'),
        headers: _jsonHeaders,
        body: jsonEncode({'status': status}),
      ),
    );
    return Session.fromJson(json as Map<String, dynamic>);
  }

  Future<String> report(
    String sessionId,
    String lang, {
    bool reset = false,
  }) async {
    final json = await _send(
      () => _client.post(
        _uri('/api/sessions/$sessionId/report?reset=$reset'),
        headers: _jsonHeaders,
        body: jsonEncode({'lang': lang}),
      ),
    );
    return (json as Map<String, dynamic>)['content'] as String;
  }

  Future<String> saveReport(
    String sessionId,
    String lang,
    String content,
  ) async {
    final json = await _send(
      () => _client.put(
        _uri('/api/sessions/$sessionId/report'),
        headers: _jsonHeaders,
        body: jsonEncode({'lang': lang, 'content': content}),
      ),
    );
    return (json as Map<String, dynamic>)['content'] as String;
  }

  Future<dynamic> _send(Future<http.Response> Function() call) async {
    final http.Response response;
    try {
      response = await call().timeout(const Duration(seconds: 30));
    } on TimeoutException {
      throw const ApiException('请求超时，请检查网络后重试');
    } on SocketException {
      throw const ApiException('无法连接后端服务');
    } on http.ClientException {
      throw const ApiException('无法连接后端服务');
    }
    return _decode(response.statusCode, response.body);
  }

  dynamic _decode(int statusCode, String body) {
    dynamic json;
    try {
      json = jsonDecode(body);
    } catch (_) {
      json = null;
    }
    if (statusCode >= 200 && statusCode < 300) return json;
    if (statusCode == 401 && _accessToken != null) {
      onUnauthorized?.call();
    }
    final detail = json is Map<String, dynamic> ? json['detail'] : null;
    final message = detail is String
        ? detail
        : detail is List
        ? detail.map((item) => item['msg'].toString()).join('；')
        : null;
    throw ApiException(message ?? '请求失败($statusCode)', statusCode: statusCode);
  }
}
