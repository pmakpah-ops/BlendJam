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

  @override
  void initState() {
    super.initState();
    playerA = AudioPlayer();
    playerB = AudioPlayer();
  }

  @override
  void dispose() {
    playerA.dispose();
    playerB.dispose();
    super.dispose();
  }

  void updateVol() {
    playerA.setVolume((1 - cross) * 2 > 1 ? 1 : (1 - cross) * 2);
    playerB.setVolume(cross * 2 > 1 ? 1 : cross * 2);
  }

  Future<void> load(bool isA) async {
    var r = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (r == null) return;
    String? p = r.files.single.path;
    String n = r.files.single.name;
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
    updateVol();
  }

  Widget deck(bool isA) {
    AudioPlayer pl = isA ? playerA : playerB;
    String? nm = isA ? nameA : nameB;
    double tp = isA ? tempoA : tempoB;
    Color c = isA ? Colors.deepPurple : Colors.orange;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(isA ? 'DECK A' : 'DECK B'),
            Text(nm ?? 'No track', style: const TextStyle(fontWeight: FontWeight.bold)),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(icon: const Icon(Icons.folder_open), onPressed: () => load(isA)),
                StreamBuilder<PlayerState>(
                  stream: pl.playerStateStream,
                  builder: (ctx, snap) {
                    bool playing = snap.data?.playing ?? false;
                    return IconButton(
                      icon: Icon(playing ? Icons.pause : Icons.play_arrow, color: c),
                      onPressed: () { playing ? pl.pause() : pl.play(); },
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
      appBar: AppBar(title: const Text('BlendJam')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          deck(true),
          Slider(
            value: cross,
            onChanged: (v) { setState(() { cross = v; }); updateVol(); },
          ),
          deck(false),
        ],
      ),
    );
  }
}
