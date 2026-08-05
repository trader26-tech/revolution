import '../../../core/network/api_client.dart';
import '../domain/health.dart';

/// Talks to the backend on behalf of the home feature.
class HomeRepository {
  HomeRepository({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;

  Future<Health> fetchHealth() async {
    final json = await _api.get('/health');
    return Health.fromJson(json as Map<String, dynamic>);
  }
}
