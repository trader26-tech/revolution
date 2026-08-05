import 'package:flutter_test/flutter_test.dart';
import 'package:revolution/features/tasks/domain/task.dart';

void main() {
  test('copyWith preserves the icon so the list can show the logo', () {
    final t = Task(id: '1', title: 'Netflix',
        iconName: 'Netflix', iconDomain: 'netflix.com');
    // A Save that only tweaks the reminder must NOT drop the icon.
    final saved = t.copyWith(reminderOn: false);
    expect(saved.iconName, 'Netflix');
    expect(saved.iconDomain, 'netflix.com');
    expect(saved.hasIcon, true);
  });

  test('a task with an icon reports hasIcon', () {
    expect(Task(id: '2', title: 'x', iconName: 'HDFC').hasIcon, true);
    expect(Task(id: '3', title: 'x').hasIcon, false);
  });
}
