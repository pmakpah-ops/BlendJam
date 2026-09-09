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
  int autoMixIndex = 0;
  bool isTransitioning = false;

  @override
  void initState() {
    super.initState();
    playerA = AudioPlayer();
    playerB = AudioPlayer();
    playerA.positionStream.listen((_) => checkAutoMix());
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
      setState(() => nameA = n);
    } else {
      await playerB.setFilePath(p);
      await playerB.setSpeed(tempoB);
      setState(() => nameB = n);
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

  void checkAutoMix() async {
    if (!autoMix || isTransitioning || queuePaths.isEmpty) return;
    var dur = playerA.duration;
    if (dur == null) return;
    var pos = playerA.position;
    if ((dur - pos).inSeconds < 15) {
      isTransitioning = true;
      autoMixIndex = (autoMixIndex + 1) % queuePaths.length;
      await playerB.setFilePath(queuePaths[autoMixIndex]);
      await playerB.setSpeed(tempoB);
      setState(() => nameB = queueNames[autoMixIndex]);
      playerB.play();
      for (int i = 0; i <= 10; i++) {
        await Future.delayed(const Duration(seconds: 1));
        if (!mounted ||!autoMix) break;
        setState(() => cross = i / 10);
        updateVol();
      }
      await playerA.stop();
      await playerA.setFilePath(queuePaths[autoMixIndex]);
      await playerA.play();
      setState(() {
        nameA = queueNames[autoMixIndex];
        cross = 0;
      });
      updateVol();
      isTransitioning = false;
    }
  }

  Widget deck(bool isA) {
    AudioPlayer pl = isA? playerA : playerB;
    String? nm = isA? nameA : nameB;
    double tp = isA? tempoA : tempoB;
    Color c = isA? Colors.deepPurple : Colors.orange;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(isA? 'DECK A' : 'DECK B'),
            Text(nm?? 'No track', style: const TextStyle(fontWeight: FontWeight.bold)),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(icon: const Icon(Icons.folder_open), onPressed: () => load(isA)),
                StreamBuilder<PlayerState>(
                  stream: pl.playerStateStream,
                  builder: (ctx, snap) {
                    bool playing = snap.data?.playing?? false;
                    return IconButton(
                      icon: Icon(playing? Icons.pause : Icons.play_arrow, color: c, size: 32),
                      onPressed: () => playing? pl.pause() : pl.play(),
                    );
                  },
                ),
              ],
            ),
            Row(
              children: [
                const Text('Tempo'),
                Expanded(
                  child: Slider(
                    value: tp,
                    min: 0.5,
                    max: 1.5,
                    onChanged: (v) {
                      setState(() { if (isA) tempoA = v; else tempoB = v; });
                      pl.setSpeed(v);
                    },
                  ),
                ),
                Text('${tp.toStringAsFixed(2)}x'),
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
          IconButton(
            icon: Badge(label: Text('${queueNames.length}'), child: const Icon(Icons.queue_music)),
            onPressed: addToQueue,
          ),
          Row(
            children: [
              const Text('Auto', style: TextStyle(fontSize: 12)),
              Switch(value: autoMix, onChanged: (v) => setState(() => autoMix = v)),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          deck(true),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                const Text('A'),
                Expanded(
                  child: Slider(
                    value: cross,
                    onChanged: (v) { setState(() => cross = v); updateVol(); },
                  ),
                ),
                const Text('B'),
              ],
            ),
          ),
          if (isTransitioning) const LinearProgressIndicator(),
          deck(false),
          const SizedBox(height: 12),
          if (queueNames.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Up Next (${queueNames.length})', style: const
