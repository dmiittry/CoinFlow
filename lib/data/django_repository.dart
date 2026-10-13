import 'dart:convert';
import 'package:http/http.dart' as http;
import '../domain/models.dart';
import 'repository.dart';

/// Prepared adapter; not constructed by the offline application.
/// Requires the future server contract described in docs/DJANGO_API.md.
class DjangoFinanceRepository implements FinanceRepository {
  final Uri endpoint;
  final String accessToken;
  final http.Client client;
  String? _etag;
  DjangoFinanceRepository({
    required this.endpoint,
    required this.accessToken,
    required this.client,
  });
  Map<String, String> get _headers => {
    'Authorization': 'Bearer $accessToken',
    'Accept': 'application/json',
  };
  @override
  Future<FinanceData> load() async {
    final response = await client
        .get(endpoint, headers: _headers)
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw StateError('Ошибка загрузки API: ${response.statusCode}');
    }
    final data = FinanceData.fromJson(
      jsonDecode(utf8.decode(response.bodyBytes)),
    );
    _etag = response.headers['etag'];
    return data;
  }

  @override
  Future<void> save(FinanceData data) async {
    data.validate();
    if (_etag == null) {
      throw StateError('Перед записью нужно загрузить данные с версией ETag');
    }
    final response = await client
        .put(
          endpoint,
          headers: {
            ..._headers,
            'Content-Type': 'application/json; charset=utf-8',
            'If-Match': _etag!,
          },
          body: jsonEncode(data.toJson()),
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode == 412) {
      throw StateError(
        'Данные изменены на сервере. Загрузите актуальную версию.',
      );
    }
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw StateError('Ошибка сохранения API: ${response.statusCode}');
    }
    _etag = response.headers['etag'];
  }
}
