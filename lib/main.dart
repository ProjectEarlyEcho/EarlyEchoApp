import 'package:flutter/material.dart';

void main() {
  runApp(const EarlyEchoApp());
}

class EarlyEchoApp extends StatelessWidget {
  const EarlyEchoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EarlyEcho',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('EarlyEcho')),
      body: const Center(child: Text('Acoustic biomarker screening')),
    );
  }
}
