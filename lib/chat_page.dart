import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:dart_openai/dart_openai.dart';
import 'package:devfest23/main.env.dart';
import 'package:devfest23/support/flutter/snackbar.dart';
import 'package:devfest23/support/flutter/spacing.dart';
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
    final snack = Snack(context);
    final recorder = useMemoized(FlutterSoundRecord.new);
    final audioPlayers = useMemoized(AudioPlayer.new);
    final openai = useMemoized(() {
      OpenAI.apiKey = kOpenAiApiKey;
      return OpenAI.instance;
    });

    final status = useState(ChatStatus.idle);
    final recordingPath = useState('');
    final transcription = useState('');
    final botText = useState('');

    Future<void> onFabPressed() async {
      final dir = await getApplicationDocumentsDirectory();

      try {
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
            status.value = ChatStatus.processing;

            final transcribeResp = await openai.audio.createTranscription(
              file: File(recordingPath.value),
              model: 'whisper-1',
            );
            transcription.value = transcribeResp.text;

            final chatResp = await openai.chat.create(
              model: 'gpt-4-1106-preview',
              messages: [
                OpenAIChatCompletionChoiceMessageModel(
                  role: OpenAIChatMessageRole.user,
                  content: [
                    OpenAIChatCompletionChoiceMessageContentItemModel.text(
                      transcription.value,
                    ),
                  ],
                ),
              ],
            );
            botText.value = chatResp.choices.first.message.content!.first.text!;

            final spokenResp = await openai.audio.createSpeech(
              model: "tts-1",
              voice: 'alloy',
              input: botText.value,
              outputDirectory: dir,
              outputFileName: 'spoken.mp3',
            );

            await audioPlayers.play(DeviceFileSource(spokenResp.path));

            status.value = ChatStatus.idle;
            break;
          case ChatStatus.processing:
            status.value = ChatStatus.idle;
            break;
        }
      } catch (e) {
        print("error: $e");
        snack.error("Something went wrong 😢");
        status.value = ChatStatus.idle;
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
        child: Padding(
          padding: 5.pt.all,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                transcription.value,
              ),
              2.pt.box,
              Text(
                botText.value,
              ),
              2.pt.box,
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
