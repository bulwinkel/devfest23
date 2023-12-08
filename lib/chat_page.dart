import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:dart_openai/dart_openai.dart';
import 'package:devfest23/main.env.dart';
import 'package:devfest23/support/flutter/snackbar.dart';
import 'package:devfest23/support/flutter/spacing.dart';
import 'package:devfest23/support/hooks/use_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_sound_record/flutter_sound_record.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

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
      final dir = await getApplicationDocumentsDirectory();
      final path = dir.path;

      try {
        switch (status.value) {
          case ChatStatus.idle:
            status.value = ChatStatus.recording;
            final recId = Uuid().v4();
            final recordingPath = join(path, '$recId.mp4');
            messages.add((
              id: recId,
              role: OpenAIChatMessageRole.user,
              message: "Recording...",
              audioPath: recordingPath,
            ));

            await recorder.start(
              path: recordingPath,
            );

            break;
          case ChatStatus.recording:
            status.value = ChatStatus.processing;
            await recorder.stop();

            final message = messages.get().last;
            print("message: $message");

            final resp = await openai.audio.createTranscription(
              file: File(message.audioPath),
              model: "whisper-1",
            );

            messages.update(
              (it) {
                return it.id == message.id;
              },
              (it) {
                return (
                  id: message.id,
                  role: message.role,
                  audioPath: message.audioPath,
                  message: resp.text,
                );
              },
            );

            final botResp = await openai.chat.create(
              model: "gpt-3.5-turbo",
              messages: [
                for (final message in messages.get())
                  OpenAIChatCompletionChoiceMessageModel(
                    role: message.role,
                    content: [
                      OpenAIChatCompletionChoiceMessageContentItemModel.text(
                        message.message,
                      ),
                    ],
                  ),
              ],
            );

            final botMessageId = Uuid().v4();
            final botMessage = (
              id: botMessageId,
              role: OpenAIChatMessageRole.assistant,
              message: botResp.choices.first.message.content?.first.text ?? "",
              audioPath: join(path, '$botMessageId.mp3')
            );
            messages.add(botMessage);

            final makeItSpeakResp = await openai.audio.createSpeech(
              model: "tts-1",
              input: botMessage.message,
              voice: "alloy",
              outputDirectory: dir,
              outputFileName: '$botMessageId.mp3',
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
      body: ListView(
        padding: 5.pt.all,
        children: [
          for (final message in messages.get())
            ListTile(
              title: Text(message.message),
              subtitle: Text(message.role.name),
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
