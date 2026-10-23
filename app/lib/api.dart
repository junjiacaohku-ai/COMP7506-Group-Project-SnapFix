import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'models.dart';

const kApiBaseUrl = 'http://127.0.0.1:8001';

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  bool get isQualityError => statusCode == 422;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({http.Client? client, this.baseUrl = kApiBaseUrl})
    : _client = client ?? http.Client();

  final http.Client _client;
  final String baseUrl;

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Future<HealthInfo> health() async {
    final json = await _send(() => _client.get(_uri('/api/health')));
    return HealthInfo.fromJson(json as Map<String, dynamic>);
  }

  Future<Session> analyzeImage(String filePath) async {
    final request = http.MultipartRequest('POST', _uri('/api/analyze/image'))
      ..files.add(await http.MultipartFile.fromPath('file', filePath));
    final streamed = await _client
        .send(request)
        .timeout(const Duration(seconds: 90));
    final body = await streamed.stream.bytesToString();
    final json = _decode(streamed.statusCode, body);
    return Session.fromJson(json as Map<String, dynamic>);
  }

  Future<Session> diagnoseManual(String brand, String errorCode) async {
    final json = await _send(
      () => _client.post(
        _uri('/api/diagnose/manual'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'brand': brand, 'error_code': errorCode}),
      ),
    );
    return Session.fromJson(json as Map<String, dynamic>);
  }

  Future<List<Session>> listSessions() async {
    final json = await _send(() => _client.get(_uri('/api/sessions')));
    return [
      for (final s in json as List) Session.fromJson(s as Map<String, dynamic>),
    ];
  }

  Future<Session> getSession(String id) async {
    final json = await _send(() => _client.get(_uri('/api/sessions/$id')));
    return Session.fromJson(json as Map<String, dynamic>);
  }

  Future<void> deleteSession(String id) async {
    await _send(() => _client.delete(_uri('/api/sessions/$id')));
  }

  Future<Session> stepFeedback(
    String sessionId,
    String stepId,
    String feedback,
  ) async {
    final json = await _send(
      () => _client.post(
        _uri('/api/sessions/$sessionId/steps/$stepId/feedback'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'feedback': feedback}),
      ),
    );
    return Session.fromJson(json as Map<String, dynamic>);
  }

  Future<String> report(String sessionId, String lang) async {
    final json = await _send(
      () => _client.post(
        _uri('/api/sessions/$sessionId/report'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'lang': lang}),
      ),
    );
    return (json as Map<String, dynamic>)['content'] as String;
  }

  Future<dynamic> _send(Future<http.Response> Function() call) async {
    final http.Response response;
    try {
      response = await call().timeout(const Duration(seconds: 30));
    } on TimeoutException {
      throw const ApiException('请求超时,请检查网络后重试');
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
    final detail = json is Map<String, dynamic>
        ? json['detail'] as String?
        : null;
    throw ApiException(detail ?? '请求失败($statusCode)', statusCode: statusCode);
  }
}
