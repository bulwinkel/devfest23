import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:dart_openai/dart_openai.dart';
import 'package:devfest23/main.env.dart';
import 'package:devfest23/support/flutter/spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_sound_record/flutter_sound_record.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class ChatPage extends HookWidget {
  const ChatPage({
    super.key,
    required this.title,
  });

  final String title;

  @override
  Widget build(BuildContext context) {
    final recorder = useMemoized(FlutterSoundRecord.new);
    final audioPlayer = useMemoized(AudioPlayer.new);
    final openai = useMemoized(() {
      OpenAI.apiKey = kOpenAiApiKey;
      return OpenAI.instance;
    });

    final isRecording = useState(false);
    final recordingPath = useState<String?>(null);
    final transcription = useState<String?>(null);

    Future<void> onFabPressed() async {
      // check if we have Mic permissions and if not request
      final hasRecordingPermission = await recorder.hasPermission();
      if (!hasRecordingPermission) {
        return;
      }

      // GUARD: toggle recording
      if (isRecording.value) {
        await recorder.stop();
        // isRecording.value = false;
        final recPath = recordingPath.value!;
        final response = await openai.audio.createTranscription(
          file: File(recPath),
          model: 'whisper-1',
        );

        transcription.value = response.text;
        isRecording.value = false;

        return;
      }

      isRecording.value = true;
      try {
        final recordingId = Uuid().v4();
        final dir = await getApplicationDocumentsDirectory();
        final path = join(dir.path, "$recordingId.mp4");
        await recorder.start(
          path: path,
        );
        recordingPath.value = path;
      } catch (e) {
        print("Recording failed: $e");
      }
    }

    Future<void> playRecording() async {
      final path = recordingPath.value;
      if (path == null) return;
      audioPlayer.play(DeviceFileSource(path));
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
              onPressed: switch (
                  recordingPath.value == null || isRecording.value) {
                true => null,
                false => playRecording,
              },
              child: const Text(
                'Play recording',
              ),
            ),
            2.pt.box,
            Text(
              transcription.value ?? 'No transcription yet',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: onFabPressed,
        tooltip: 'Increment',
        child: isRecording.value
            ? const CircularProgressIndicator()
            : const Icon(Icons.mic),
      ),
    );
  }
}