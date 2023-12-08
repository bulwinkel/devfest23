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
    final player = useMemoized(AudioPlayer.new);
    final openai = useMemoized(() {
      OpenAI.apiKey = kOpenAiApiKey;
      return OpenAI.instance;
    });

    final status = useState(ChatStatus.idle);
    final text = useState('');
    final bot = useState('');

    Future<void> onFabPressed() async {
      final dir = await getApplicationDocumentsDirectory();
      final path = dir.path;
      final recordingPath = join(path, 'recording.mp4');

      try {
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
            final resp = await openai.audio.createTranscription(
              file: File(recordingPath),
              model: "whisper-1",
            );
            text.value = resp.text;

            final botResp = await openai.chat.create(
              model: "gpt-3.5-turbo",
              messages: [
                OpenAIChatCompletionChoiceMessageModel(
                  role: OpenAIChatMessageRole.user,
                  content: [
                    OpenAIChatCompletionChoiceMessageContentItemModel.text(
                      text.value,
                    ),
                  ],
                ),
              ],
            );
            bot.value = botResp.choices.first.message.content?.first.text ?? "";

            final makeItSpeakResp = await openai.audio.createSpeech(
              model: "tts-1",
              input: bot.value,
              voice: "alloy",
              outputDirectory: dir,
              outputFileName: "bot.mp3",
            );

            await player.play(DeviceFileSource(makeItSpeakResp.path));

            status.value = ChatStatus.idle;
            break;
          case ChatStatus.processing:
            break;
        }
      } catch (e) {
        snack.error("Some didn't work");
        status.value = ChatStatus.idle;
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
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(text.value),
              2.pt.box,
              Text(bot.value),
              2.pt.box,
              TextButton(
                onPressed: play,
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
