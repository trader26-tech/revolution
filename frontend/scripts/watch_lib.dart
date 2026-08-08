// Watches lib/ for .dart changes and prints "CHANGED" (debounced) to stdout.
// Pure dart:io — no packages. Driven by scripts/autodeploy.sh, which reacts to
// each CHANGED line by rebuilding + deploying to the phone.
//
// Run:  dart run scripts/watch_lib.dart
import 'dart:async';
import 'dart:io';

const _debounce = Duration(milliseconds: 900); // wait for you to stop typing

Future<void> main() async {
  final root = Directory('lib');
  if (!root.existsSync()) {
    stderr.writeln('lib/ not found — run from the frontend/ dir.');
    exit(1);
  }

  Timer? debounce;
  var pending = false;

  void fire() {
    debounce?.cancel();
    debounce = Timer(_debounce, () {
      if (pending) {
        pending = false;
        stdout.writeln('CHANGED'); // autodeploy.sh reacts to this line
      }
    });
  }

  // Recursive watch. On macOS this covers the whole subtree in one call.
  root.watch(events: FileSystemEvent.all, recursive: true).listen((e) {
    if (!e.path.endsWith('.dart')) return;
    // Ignore generated/ephemeral churn.
    if (e.path.contains('.dart_tool') || e.path.contains('/generated')) return;
    pending = true;
    fire();
  });

  stdout.writeln('WATCHING lib/ — save any .dart file to auto-deploy.');
  // Keep alive forever.
  await Completer<void>().future;
}
