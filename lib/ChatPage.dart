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

enum ChatStatus {
  idle,
  recording,
  processing,
}

enum ChatMessageSender {
  user,
  bot,
}

typedef ChatMessage = ({
  String id,
  ChatMessageSender sender,
  String message,
});

extension on ChatMessage {
  String get audioFileName {
    final extension = switch (sender) {
      ChatMessageSender.user => "mp4",
      ChatMessageSender.bot => "mp3",
    };
    return "$id.$extension";
  }
}

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

    final status = useState(ChatStatus.idle);
    final messages = useState<List<ChatMessage>>([]);

    Future<void> onFabPressed() async {
      // check if we have Mic permissions and if not request
      final hasRecordingPermission = await recorder.hasPermission();
      if (!hasRecordingPermission) {
        return;
      }

      final dir = await getApplicationDocumentsDirectory();
      String audioPath(String fileName) => join(dir.path, fileName);

      switch (status.value) {
        case ChatStatus.idle:
          status.value = ChatStatus.recording;
          try {
            final recordingId = Uuid().v4();
            final path = join(dir.path, "$recordingId.mp4");
            await recorder.start(
              path: path,
            );

            messages.value = [
              ...messages.value,
              (
                id: recordingId,
                sender: ChatMessageSender.user,
                message: "Recording...",
              ),
            ];
          } catch (e) {
            print("Recording failed: $e");
          }
          break;

        case ChatStatus.recording:
          status.value = ChatStatus.processing;

          await recorder.stop();
          // status.value = false;
          final recPath = audioPath(messages.value.last.audioFileName);
          final response = await openai.audio.createTranscription(
            file: File(recPath),
            model: 'whisper-1',
          );

          messages.value = [
            ...messages.value.map((it) {
              if (it.id == messages.value.last.id) {
                return (
                  id: it.id,
                  sender: it.sender,
                  message: response.text,
                );
              }
              return it;
            }),
          ];

          final chatResp = await openai.chat.create(
            model: "gpt-4-1106-preview",
            messages: [
              OpenAIChatCompletionChoiceMessageModel(
                role: OpenAIChatMessageRole.user,
                content: [
                  OpenAIChatCompletionChoiceMessageContentItemModel.text(
                    response.text,
                  ),
                ],
              ),
            ],
          );

          final chatRespText = chatResp.choices.first.message.content
                  ?.firstWhere(
                    (element) => element.type == "text",
                  )
                  .text ??
              "";

          // handle empty response
          if (chatRespText.isEmpty) {
            //TODO:KB 7/12/2023 handle empty response
            status.value = ChatStatus.idle;
            return;
          }

          final aiMessage = (
            id: Uuid().v4(),
            sender: ChatMessageSender.bot,
            message: chatRespText,
          );
          messages.value = [
            ...messages.value,
            aiMessage,
          ];

          final mp3 = await openai.audio.createSpeech(
            model: "tts-1",
            // voice: "alloy",
            voice: "echo",
            input: chatRespText,
            outputFileName: aiMessage.audioFileName,
            outputDirectory: dir,
          );

          await audioPlayer.play(DeviceFileSource(mp3.path));

          status.value = ChatStatus.idle;
          break;

        case ChatStatus.processing:
          break;
      }
    }

    Future<void> playLatest() async {
      final msgs = messages.value;
      if (msgs.isEmpty) return;
      final dir = await getApplicationDocumentsDirectory();
      final path = join(dir.path, msgs.last.audioFileName);

      await audioPlayer.play(DeviceFileSource(path));
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
              title: Text(
                message.message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: message.sender == ChatMessageSender.user
                          ? Theme.of(context).colorScheme.secondary
                          : null,
                    ),
              ),
              subtitle: Text(
                message.sender == ChatMessageSender.user
                    ? "You"
                    : "DevFest Bot",
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.tertiary,
                    ),
              ),
            ),
          if (messages.value.isNotEmpty) ...[
            2.pt.box,
            TextButton(
              onPressed: switch (status.value) {
                ChatStatus.recording => null,
                ChatStatus.processing => null,
                ChatStatus.idle => playLatest,
              },
              child: const Text(
                'Play latest',
              ),
            ),
          ],
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: onFabPressed,
        tooltip: 'Increment',
        child: switch (status.value) {
          ChatStatus.recording => const Icon(Icons.stop),
          ChatStatus.processing => const CircularProgressIndicator(),
          ChatStatus.idle => const Icon(Icons.mic),
        },
      ),
    );
  }
}
