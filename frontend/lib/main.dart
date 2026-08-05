import 'package:flutter/material.dart';

void main() => runApp(const RevolutionApp());

class RevolutionApp extends StatelessWidget {
  const RevolutionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Revolution',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      home: const Scaffold(
        body: Center(child: Text('Revolution')),
      ),
    );
  }
}
