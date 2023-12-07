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
import 'package:uuid/uuid.dart';

enum ChatStatus {
  idle,
  recording,
  processing,
}

enum ChatMessageRole {
  user,
  bot,
}

typedef ChatMessage = ({
  String id,
  String text,
  String audioPath,
  ChatMessageRole role,
});

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
    final messages = useState(<ChatMessage>[]);

    Future<void> onFabPressed() async {
      final dir = await getApplicationDocumentsDirectory();

      try {
        switch (status.value) {
          case ChatStatus.idle:
            status.value = ChatStatus.recording;

            final recId = Uuid().v4();
            final path = join(dir.path, '$recId.mp4');
            await recorder.start(
              path: path,
            );

            messages.value = [
              ...messages.value,
              (
                id: recId,
                text: 'Recording...',
                audioPath: path,
                role: ChatMessageRole.user,
              ),
            ];

            break;
          case ChatStatus.recording:
            await recorder.stop();
            status.value = ChatStatus.processing;

            final message = messages.value.last;
            final recordingPath = message.audioPath;

            final transcribeResp = await openai.audio.createTranscription(
              file: File(recordingPath),
              model: 'whisper-1',
            );

            messages.value = [
              ...messages.value.map((it) {
                if (it.id == message.id) {
                  return (
                    id: it.id,
                    text: transcribeResp.text,
                    audioPath: it.audioPath,
                    role: it.role,
                  );
                }
                return it;
              }),
            ];

            final chatResp = await openai.chat.create(
              model: 'gpt-4-1106-preview',
              messages: [
                for (final message in messages.value)
                  OpenAIChatCompletionChoiceMessageModel(
                    role: switch (message.role) {
                      ChatMessageRole.user => OpenAIChatMessageRole.user,
                      ChatMessageRole.bot => OpenAIChatMessageRole.assistant,
                    },
                    content: [
                      OpenAIChatCompletionChoiceMessageContentItemModel.text(
                        message.text,
                      ),
                    ],
                  ),
              ],
            );

            final id = Uuid().v4();
            final botMessage = (
              id: id,
              text: chatResp.choices.first.message.content?.first.text ?? '',
              audioPath: '',
              role: ChatMessageRole.bot,
            );

            messages.value = [
              ...messages.value,
              botMessage,
            ];

            final spokenResp = await openai.audio.createSpeech(
              model: "tts-1",
              voice: 'alloy',
              input: botMessage.text,
              outputDirectory: dir,
              outputFileName: botMessage.audioPath,
            );

            messages.value = [
              ...messages.value.map((it) {
                if (it.id == id) {
                  return (
                    id: it.id,
                    text: it.text,
                    audioPath: spokenResp.path,
                    role: it.role,
                  );
                }
                return it;
              }),
            ];

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

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(title),
      ),
      body: ListView(
        padding: 5.pt.all,
        children: <Widget>[
          for (final message in messages.value)
            ListTile(
                title: Text(message.text),
                leading: switch (message.role) {
                  ChatMessageRole.user => const Icon(Icons.person),
                  ChatMessageRole.bot => const Icon(Icons.android),
                },
                onTap: () async {
                  if (audioPlayers.state == PlayerState.playing) {
                    await audioPlayers.stop();
                    return;
                  }
                  await audioPlayers.play(
                    DeviceFileSource(message.audioPath),
                  );
                }),
        ],
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
