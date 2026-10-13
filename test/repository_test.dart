import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:coin_flow/application/app_controller.dart';
import 'package:coin_flow/data/demo_data.dart';
import 'package:coin_flow/data/django_repository.dart';
import 'package:coin_flow/data/repository.dart';
import 'package:coin_flow/domain/models.dart';

class FailingRepository implements FinanceRepository {
  @override
  Future<FinanceData> load() async => demoData();
  @override
  Future<void> save(FinanceData data) async => throw StateError('disk full');
}

void main() {
  test(
    'failed save leaves current data intact and unlocks controller',
    () async {
      SharedPreferences.setMockInitialValues({});
      final c = AppController(
        FailingRepository(),
        await SharedPreferences.getInstance(),
      );
      await c.initialize();
      final before = c.data;
      await expectLater(
        c.replace(FinanceData(cards: [], entries: [])),
        throwsStateError,
      );
      expect(identical(before, c.data), isTrue);
      expect(c.busy, isFalse);
    },
  );
  test(
    'Django adapter sends JSON, bearer token and revision, rejects conflict',
    () async {
      var writes = 0;
      final original = demoData();
      final client = MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer test-token');
        if (request.method == 'GET') {
          return http.Response(
            jsonEncode(original.toJson()),
            200,
            headers: {
              'etag': '"1"',
              'content-type': 'application/json; charset=utf-8',
            },
          );
        }
        expect(request.headers['If-Match'], writes == 0 ? '"1"' : '"2"');
        expect(jsonDecode(request.body), original.toJson());
        writes++;
        return http.Response(
          '',
          writes == 1 ? 204 : 412,
          headers: {'etag': '"2"'},
        );
      });
      final repo = DjangoFinanceRepository(
        endpoint: Uri.parse('https://example.test/api/v1/finance/snapshot/'),
        accessToken: 'test-token',
        client: client,
      );
      await expectLater(repo.save(original), throwsStateError);
      expect((await repo.load()).toJson(), original.toJson());
      await repo.save(original);
      await expectLater(repo.save(original), throwsStateError);
      client.close();
    },
  );
}
