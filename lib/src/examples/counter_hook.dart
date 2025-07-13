import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

/// A simple counter widget implemented using Flutter Hooks
class CounterHookWidget extends HookWidget {
  const CounterHookWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final counter = useState(0);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Counter Hook Example'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Count: ${counter.value}',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => counter.value++,
              child: const Text('Increment'),
            ),
          ],
        ),
      ),
    );
  }
} 