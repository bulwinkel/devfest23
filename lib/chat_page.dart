import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

class ChatPage extends HookWidget {
  const ChatPage({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final counterState = useState(0);
    final counter = counterState.value;

    void incrementCounter() {
      counterState.value++;
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'Push me to increment:',
            ),
            Text(
              '$counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
