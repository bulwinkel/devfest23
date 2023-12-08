import 'package:audioplayers/audioplayers.dart';
import 'package:dart_openai/dart_openai.dart';
import 'package:devfest23/main.env.dart';
import 'package:devfest23/support/flutter/snackbar.dart';
import 'package:devfest23/support/flutter/spacing.dart';
import 'package:devfest23/support/hooks/use_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_sound_record/flutter_sound_record.dart';

enum ChatStatus {
  idle,
  recording,
  processing,
}

typedef ChatMessage = ({
  String id,
  OpenAIChatMessageRole role,
  String message,
  String audioPath,
});

class ChatPage extends HookWidget {
  const ChatPage({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final snack = Snack(context);
    final recorder = useMemoized(FlutterSoundRecord.new);
    final player = useMemoized(AudioPlayer.new);
    final openai = useMemoized(() {
      OpenAI.apiKey = kOpenAiApiKey;
      return OpenAI.instance;
    });

    final status = useState(ChatStatus.idle);
    final messages = useList(<ChatMessage>[]);

    Future<void> onFabPressed() async {
      try {
        switch (status.value) {
          case ChatStatus.idle:
            break;
          case ChatStatus.recording:
            break;
          case ChatStatus.processing:
            break;
        }
      } catch (e) {
        snack.error("Uh oh, something went wrong! 🙃");
        status.value = ChatStatus.idle;
      }
    }

    Future<void> togglePlay(ChatMessage message) async {
      if (status.value != ChatStatus.idle) return;

      if (player.state == PlayerState.playing) {
        await player.stop();
      } else {
        await player.play(DeviceFileSource(message.audioPath));
      }
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(title),
        actions: [
          IconButton(
            onPressed: () {
              messages.clear();
            },
            icon: Icon(Icons.delete_sweep),
          ),
        ],
      ),
      body: ListView(
        padding: 5.pt.all,
        children: [
          for (final message in messages.get())
            ListTile(
              title: Text(message.message),
              subtitle: Text(message.role.name),
              onTap: () => togglePlay(message),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: onFabPressed,
        tooltip: 'Increment',
        child: switch (status.value) {
          ChatStatus.idle => Icon(Icons.mic),
          ChatStatus.recording => Icon(Icons.stop),
          ChatStatus.processing => CircularProgressIndicator(),
        },
      ),
    );
  }
}
