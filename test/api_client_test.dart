import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:labconnect_admin/core/network/api_client.dart';
import 'package:labconnect_admin/core/network/api_exception.dart';
import 'package:labconnect_admin/core/network/token_storage.dart';
import 'package:labconnect_admin/data/repositories/auth_repository.dart';

void main() {
  test('404 errors identify the API endpoint that was not found', () async {
    final client = ApiClient(
      tokens: TokenStorage(),
      httpClient: MockClient((request) async {
        expect(request.url.path, '/api/v1/auth/login/');
        return http.Response(
          '{"detail":"Not found"}',
          404,
          request: request,
        );
      }),
    );
    addTearDown(client.close);

    await expectLater(
      client.post(
        '/auth/login/',
        auth: false,
        body: const {'username': 'test'},
      ),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'message',
          'Not found at /api/v1/auth/login/ (HTTP 404)',
        ),
      ),
    );
  });

  test('login omits tenant when server default tenant is configured', () async {
    final client = ApiClient(
      tokens: TokenStorage(),
      httpClient: MockClient((request) async {
        expect(request.url.path, '/api/v1/auth/login/');
        expect(
          request.body,
          '{"username":"test","password":"password"}',
        );
        return http.Response(
          '{"detail":"Invalid credentials"}',
          401,
          request: request,
        );
      }),
    );
    addTearDown(client.close);
    final auth = AuthRepository(api: client, tokens: TokenStorage());

    await expectLater(
      auth.login(username: 'test', password: 'password', tenant: ''),
      throwsA(isA<ApiException>()),
    );
  });
}
