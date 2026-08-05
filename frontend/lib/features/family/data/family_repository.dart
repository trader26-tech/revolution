import '../../../core/network/api_client.dart';
import '../domain/family_member.dart';

/// Talks to the FastAPI family endpoints, scoped by the head-of-family account
/// (the `X-Owner-Id` header). Listing auto-creates the head's own "You" record
/// on the backend, so the family always has at least one member.
class FamilyRepository {
  FamilyRepository({ApiClient? api, String? ownerId})
      : _api = api ?? ApiClient(),
        _ownerId = (ownerId != null && ownerId.isNotEmpty)
            ? ownerId
            : _placeholderOwnerId;

  final ApiClient _api;
  final String _ownerId;

  static const String _placeholderOwnerId = 'demo-user';

  Map<String, String> get _ownerHeader => {'X-Owner-Id': _ownerId};

  Future<List<FamilyMember>> list() async {
    final json = await _api.get('/family/members', headers: _ownerHeader);
    return (json as List)
        .map((e) => FamilyMember.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<FamilyMember> create(FamilyMemberDraft draft) async {
    final json = await _api.post(
      '/family/members',
      body: draft.toJson(),
      headers: _ownerHeader,
    );
    return FamilyMember.fromJson(json as Map<String, dynamic>);
  }

  Future<FamilyMember> update(
    String id, {
    String? name,
    String? relation,
  }) async {
    final json = await _api.patch(
      '/family/members/$id',
      body: {
        if (name != null) 'name': name,
        if (relation != null) 'relation': relation,
      },
      headers: _ownerHeader,
    );
    return FamilyMember.fromJson(json as Map<String, dynamic>);
  }

  Future<void> delete(String id) async {
    await _api.delete('/family/members/$id', headers: _ownerHeader);
  }
}
