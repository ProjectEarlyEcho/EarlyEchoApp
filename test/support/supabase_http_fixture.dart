import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

const ownerA = '10000000-0000-0000-0000-000000000001';
const ownerB = '10000000-0000-0000-0000-000000000002';

/// Real SupabaseClient HTTP transport against an isolated loopback endpoint.
/// Database permissions and transactional RPC behavior are tested separately
/// against PostgreSQL by supabase/tests/test_sync_integrity.py.
class SupabaseHttpFixture {
  SupabaseHttpFixture._(this.server)
    : client = SupabaseClient(
        'http://127.0.0.1:${server.port}',
        'test-anon-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );

  final HttpServer server;
  final SupabaseClient client;

  static Future<SupabaseHttpFixture> start(
    Future<void> Function(HttpRequest request) handle,
  ) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      try {
        await handle(request);
      } catch (error) {
        await respond(request, {'message': error.toString()}, status: 500);
        rethrow;
      }
    });
    return SupabaseHttpFixture._(server);
  }

  Future<void> signIn(String owner) => client.auth.setInitialSession(
    jsonEncode({
      'access_token': tokenFor(owner),
      'token_type': 'bearer',
      'user': {'id': owner},
    }),
  );

  static String tokenFor(String owner) {
    String part(Object value) =>
        base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
    return '${part({'alg': 'none'})}.${part({'sub': owner, 'role': 'authenticated', 'exp': 4102444800})}.test';
  }

  static Future<void> respond(
    HttpRequest request,
    Object? body, {
    int status = 200,
  }) async {
    request.response.statusCode = status;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(body));
    await request.response.close();
  }

  Future<void> close() async {
    await client.dispose();
    await server.close(force: true);
  }
}
