import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_sound_record/flutter_sound_record.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

enum ChatStatus {
  idle,
  recording,
  processing,
}

class ChatPage extends HookWidget {
  const ChatPage({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final recorder = useMemoized(FlutterSoundRecord.new);
    final audioPlayers = useMemoized(AudioPlayer.new);

    final status = useState(ChatStatus.idle);
    final recordingPath = useState('');

    Future<void> onFabPressed() async {
      final dir = await getApplicationDocumentsDirectory();

      switch (status.value) {
        case ChatStatus.idle:
          status.value = ChatStatus.recording;

          final path = join(dir.path, 'recording.mp4');
          await recorder.start(
            path: path,
          );
          recordingPath.value = path;
          break;
        case ChatStatus.recording:
          await recorder.stop();
          // status.value = ChatStatus.processing;
          status.value = ChatStatus.idle;
          break;
        case ChatStatus.processing:
          status.value = ChatStatus.idle;
          break;
      }
    }

    Future<void> playRecording() async {
      if (recordingPath.value.isEmpty || status.value != ChatStatus.idle) {
        return;
      }

      await audioPlayers.play(DeviceFileSource(recordingPath.value));
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
            TextButton(
              onPressed: switch (status.value == ChatStatus.idle &&
                  recordingPath.value.isNotEmpty) {
                true => playRecording,
                false => null,
              },
              child: Text(
                'Push to play',
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: onFabPressed,
        tooltip: switch (status.value) {
          ChatStatus.idle => 'Start recording',
          ChatStatus.recording => 'Stop recording',
          ChatStatus.processing => 'Processing',
        },
        child: switch (status.value) {
          ChatStatus.idle => const Icon(Icons.mic),
          ChatStatus.recording => const Icon(Icons.stop),
          ChatStatus.processing => CircularProgressIndicator(),
        },
      ),
    );
  }
}
