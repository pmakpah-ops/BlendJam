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

  @override
  void dispose() {
    playerA.dispose();
    playerB.dispose();
    super.dispose();
  }

  void updateVol() {
    double a = (1 - cross) * 2;
    double b = cross * 2;
    if (a > 1) a = 1;
    if (b > 1) b = 1;
    playerA.setVolume(a);
    playerB.setVolume(b);
  }

  Future<void> playNextAuto(AudioPlayer ended) async {
    if (!autoMix) return;
    if (queuePaths.isEmpty) return;
    if (!mounted) return;
    autoMixIndex = (autoMixIndex + 1) % queuePaths.length;
    AudioPlayer nextPlayer = (ended == playerA)? playerB : playerA;
    String p = queuePaths[autoMixIndex];
    String n = queueNames[autoMixIndex];
    await nextPlayer.setFilePath(p);
    if (nextPlayer == playerA) {
      await playerA.setSpeed(tempoA);
      setState(() { nameA = n; cross = 0; });
    } else {
      await playerB.setSpeed(tempoB);
      setState(() { nameB = n; cross = 1; });
    }
    updateVol();
    nextPlayer.play();
  }

  Future<void> load(bool isA, [String? qPath, String? qName]) async {
    String? p = qPath;
    String? n = qName;
    if (p == null) {
      var r = await FilePicker.platform.pickFiles(type: FileType.audio);
      if (r == null) return;
      p = r.files.single.path;
      n = r.files.single.name;
    }
    if (p == null) return;
    if (isA) {
      await playerA.setFilePath(p);
      await playerA.setSpeed(tempoA);
      setState(() { nameA = n; });
    } else {
      await playerB.setFilePath(p);
      await playerB.setSpeed(tempoB);
      setState(() { nameB = n; });
    }
    if (qPath!= null) {
      int idx = queuePaths.indexOf(qPath);
      if (idx!= -1) autoMixIndex = idx;
    }
    updateVol();
  }

  Future<void> addToQueue() async {
    var r = await FilePicker.platform.pickFiles(type: FileType.audio, allowMultiple: true);
    if (r == null) return;
    setState(() {
      for (var f in r.files) {
        if (f.path!= null) {
          queuePaths.add(f.path!);
          queueNames.add(f.name);
        }
      }
    });
  }

  Future<void> startQueueAuto() async {
    if (queuePaths.isEmpty) return;
    autoMixIndex = 0;
    await playerA.setFilePath(queuePaths[0]);
    setState(() { nameA = queueNames[0]; cross = 0; autoMix = true; });
    updateVol();
    playerA.play();
  }

  Widget buildDeck(bool isA) {
    String? nm = isA? nameA : nameB;
    double tp = isA? tempoA : tempoB;
    AudioPlayer pl = isA? playerA : playerB;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(isA? 'DECK A' : 'DECK B'),
            Text(nm?? 'No track'),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(icon: const Icon(Icons.folder_open), onPressed: () => load(isA)),
                IconButton(icon: const Icon(Icons.play_arrow), onPressed: () => pl.play()),
                IconButton(icon: const Icon(Icons.pause), onPressed: () => pl.pause()),
              ],
            ),
            Row(
              children: [
                const Text('Tempo'),
                Expanded(
                  child: Slider(
                    value: tp, min: 0.5, max: 1.5,
                    onChanged: (v) {
                      setState(() { if (isA) tempoA = v; else tempoB = v; });
                      pl.setSpeed(v);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BlendJam'),
        actions: [
          IconButton(icon: const Icon(Icons.queue_music), onPressed: addToQueue),
          const Center(child: Text('Auto', style: TextStyle(fontSize: 12))),
          Switch(
            value: autoMix,
            onChanged: (v) {
              setState(() { autoMix = v; });
              if (v && queuePaths.isNotEmpty) startQueueAuto();
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          buildDeck(true),
          Row(
            children: [
              const Text('A'),
              Expanded(child: Slider(value: cross, onChanged: (v) { setState(() { cross = v; }); updateVol(); })),
              const Text('B'),
            ],
          ),
          buildDeck(false),
          const SizedBox(height: 12),
          if (queueNames.isEmpty)
            OutlinedButton.icon(icon: const Icon(Icons.add), label: const Text('Add songs to queue'), onPressed: addToQueue)
          else
            Card(
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Padding(padding: EdgeInsets.all(8), child: Text('Up Next')),
                      Row(
                        children: [
                          TextButton(onPressed: startQueueAuto, child: const Text('Play All Auto')),
                          TextButton(onPressed: () => setState(() { queuePaths.clear(); queueNames.clear(); autoMixIndex = -1; }), child: const Text('Clear')),
                        ],
                      ),
                    ],
                  ),
                  for (int i = 0; i < queueNames.length; i++)
                    ListTile(
                      dense: true,
                      title: Text(queueNames[i]),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(icon: const Icon(Icons.play_arrow), onPressed: () => load(true, queuePaths[i], queueNames[i])),
                          IconButton(icon: const Icon(Icons.arrow_downward), onPressed: () => load(false, queuePaths[i], queueNames[i])),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
