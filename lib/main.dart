import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:file_picker/file_picker.dart';

void main() => runApp(const BlendJamApp());

class BlendJamApp extends StatelessWidget {
  const BlendJamApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BlendJam',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const DJPage(),
    );
  }
}

class DJPage extends StatefulWidget {
  const DJPage({super.key});
  @override
  State<DJPage> createState() => DJState();
}

class DJState extends State<DJPage> {
  late AudioPlayer playerA;
  late AudioPlayer playerB;
  String? nameA;
  String? nameB;
  double tempoA = 1.0;
  double tempoB = 1.0;
  double cross = 0.5;
  List<String> queuePaths = [];
  List<String> queueNames = [];
  bool autoMix = false;
  int autoMixIndex = -1;

  @override
  void initState() {
    super.initState();
    playerA = AudioPlayer();
    playerB = AudioPlayer();
    setupAutoMix();
  }

  void setupAutoMix() {
    playerA.playerStateStream.listen((s) {
      if (s.processingState == ProcessingState.completed) {
        playNextAuto(playerA);
      }
    });
    playerB.playerStateStream.listen((s) {
      if (s.processingState == ProcessingState.completed) {
        playNextAuto(playerB);
      }
    });
  }

  void playNextAuto(AudioPlayer ended) async {
    if (!autoMix) return;
    if (queuePaths.isEmpty) return;
    if (!mounted) return;

    autoMixIndex = (autoMixIndex + 1) % queuePaths.length;
    String nextPath = queuePaths[autoMixIndex];
    String nextName = queueNames[autoMixIndex];

    AudioPlayer nextPlayer = (ended == playerA)? playerB : playerA;

    await nextPlayer.setFilePath(nextPath);
    if (nextPlayer == playerA) {
      await playerA.setSpeed(tempoA);
      setState(() { nameA = nextName; });
    } else {
      await playerB.setSpeed(tempoB);
      setState(() { nameB = nextName; });
    }
    updateVol();
    nextPlayer.play();

    // simple auto crossfade to the new deck
    if (nextPlayer == playerB) {
      for (int i = 0; i <= 10; i++) {
        await Future.delayed
