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
    final player = useMemoized(AudioPlayer.new);

    final status = useState(ChatStatus.idle);

    Future<void> onFabPressed() async {
      final dir = await getApplicationDocumentsDirectory();
      final path = dir.path;
      final recordingPath = join(path, 'recording.mp4');

      switch (status.value) {
        case ChatStatus.idle:
          status.value = ChatStatus.recording;
          await recorder.start(
            path: recordingPath,
          );
          break;
        case ChatStatus.recording:
          status.value = ChatStatus.processing;
          await recorder.stop();
          status.value = ChatStatus.idle;
          break;
        case ChatStatus.processing:
          break;
      }
    }

    Future<void> play() async {
      final dir = await getApplicationDocumentsDirectory();
      final path = dir.path;
      final recordingPath = join(path, 'recording.mp4');
      await player.play(DeviceFileSource(recordingPath));
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
              onPressed: play,
              child: Text(
                'Push to play',
              ),
            ),
          ],
        ),
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
