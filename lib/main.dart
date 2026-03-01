import 'package:flutter/material.dart';

void main() {
  runApp(const GratitudeApp());
}

class GratitudeApp extends StatelessWidget {
  const GratitudeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Gratitude OCR',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
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
    final today = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gratitude'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${today.month}/${today.day}/${today.year}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {},
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Text('Scan handwritten list'),
                ),
              ),
            ),
            const SizedBox(height: 30),
            Text(
              'Recent Entries',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: 3,
                itemBuilder: (context, index) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text('Placeholder gratitude entry ${index + 1}'),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}