import 'package:flutter/foundation.dart';

import '../../family/data/family_repository.dart';
import '../../family/domain/family_member.dart';
import '../data/reminders_repository.dart';
import '../domain/reminder.dart';
import '../domain/streak.dart';

/// Shared reminder state for the whole signed-in session.
///
/// Both the Home tab and the Calendar tab read from this one source, so Bobo's
/// mood, the streak, and the list stay in lock-step and we fetch once. Lives for
/// the lifetime of the shell and is disposed when the user signs out.
///
/// It also holds the family members, so any reminder can be shown against the
/// person it belongs to (via [memberFor]) without each screen re-fetching.
class RemindersController extends ChangeNotifier {
  RemindersController({
    required RemindersRepository repository,
    FamilyRepository? familyRepository,
  })  : _repo = repository,
        _familyRepo =
            familyRepository ?? FamilyRepository(ownerId: repository.ownerId);

  final RemindersRepository _repo;
  final FamilyRepository _familyRepo;

  /// Exposed so screens can hand the same repository to the add-reminder sheet.
  RemindersRepository get repository => _repo;

  List<Reminder> _reminders = [];
  bool _loading = true;
  Object? _error;

  List<FamilyMember> _members = [];
  Map<String, FamilyMember> _membersById = {};

  List<Reminder> get reminders => _reminders;
  bool get loading => _loading;
  Object? get error => _error;

  List<FamilyMember> get members => _members;

  /// The family member a reminder belongs to, or null if unlinked/unknown.
  FamilyMember? memberFor(Reminder r) =>
      r.memberId == null ? null : _membersById[r.memberId];

  StreakStatus get streak => StreakStatus.from(_reminders);

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      // Fetch reminders and members together; members are best-effort so a
      // family failure never blocks the reminders list.
      final results = await Future.wait([
        _repo.list(),
        _familyRepo.list().catchError((_) => <FamilyMember>[]),
      ]);
      _reminders = results[0] as List<Reminder>;
      _members = results[1] as List<FamilyMember>;
      _membersById = {for (final m in _members) m.id: m};
      _error = null;
    } catch (e) {
      _error = e;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<Reminder> create(ReminderDraft draft) async {
    final created = await _repo.create(draft);
    addCreated(created);
    return created;
  }

  /// Insert an already-created reminder (e.g. one the add-sheet made directly)
  /// into the shared list so every tab updates.
  void addCreated(Reminder created) {
    _reminders = [..._reminders, created]
      ..sort((a, b) => a.remindOn.compareTo(b.remindOn));
    notifyListeners();
  }

  /// Optimistically remove, roll back on failure.
  Future<void> delete(Reminder r) async {
    final previous = _reminders;
    _reminders = _reminders.where((x) => x.id != r.id).toList();
    notifyListeners();
    try {
      await _repo.delete(r.id);
    } catch (_) {
      _reminders = previous;
      notifyListeners();
      rethrow;
    }
  }
}
