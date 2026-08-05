import 'package:flutter/material.dart';

import '../data/home_repository.dart';
import '../domain/health.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _repo = HomeRepository();
  Future<Health>? _health;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Revolution')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Flutter frontend is wired up.'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => setState(() => _health = _repo.fetchHealth()),
              child: const Text('Ping backend /health'),
            ),
            const SizedBox(height: 16),
            if (_health != null)
              FutureBuilder<Health>(
                future: _health,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const CircularProgressIndicator();
                  }
                  if (snap.hasError) {
                    return Text('Error: ${snap.error}');
                  }
                  return Text('Backend status: ${snap.data!.status}');
                },
              ),
          ],
        ),
      ),
    );
  }
}
