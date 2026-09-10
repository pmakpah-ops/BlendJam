import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';

void main() => runApp(const BlendJamApp());

class BlendJamApp extends StatelessWidget {
  const BlendJamApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(title: 'BlendJam', debugShowCheckedModeBanner: false, theme: ThemeData.dark(), home: const DJPage());
  }
}

class DJPage extends StatefulWidget {
  const DJPage({super.key});
  @override State<DJPage> createState() => DJState();
}

class DJState extends State<DJPage> {
  late AudioPlayer playerA; late AudioPlayer playerB;
  String? nameA; String? nameB;
  double cross = 0.0;
  List<String> queuePaths = []; List<String> queueNames = [];
  bool autoMix = false; int autoMixIndex = -1;
  bool isBlending = false; Timer? blendTimer;
  Map<String, double> silenceMap = {}; // path -> trailing silence secs

  @override
  void initState() {
    super.initState();
    playerA = AudioPlayer(); playerB = AudioPlayer();
    updateVol();
    blendTimer = Timer.periodic(const Duration(milliseconds: 500), (_) => checkBlend());
  }

  @override void dispose() { blendTimer?.cancel(); playerA.dispose(); playerB.dispose(); super.dispose(); }

  void updateVol() {
    double a = (1 - cross).clamp(0.0, 1.0);
    double b = cross.clamp(0.0, 1.0);
    playerA.setVolume(a); playerB.setVolume(b);
  }

  Future<double> detectTrailingSilence(String path) async {
    try {
      final session = await FFmpegKit.execute(
        '-i "$path" -af silencedetect=noise=-60dB:d=1 -f null -'
      );
      final logs = await session.getAllLogsAsString();
      if (logs == null || logs.isEmpty) return 5.0;
      final durRegex = RegExp(r'silence_duration:\s*([\d.]+)');
      final matches = durRegex.allMatches(logs).toList();
      if (matches.isEmpty) return 0.0;
      // Take last silence chunk as trailing silence, clamp 0-12s
      final lastDur = double.tryParse(matches.last.group(1)?? '0')?? 0.0;
      // Only trust it if it appears near the end of logs (heuristic)
      // Simple: return it clamped
      return lastDur.clamp(0.0, 12.0).toDouble();
    } catch (_) {
      return 5.0;
    }
  }

  Future<void> checkBlend() async {
    if (!autoMix || isBlending || queuePaths.isEmpty) return;
    AudioPlayer current = (cross < 0.5)? playerA : playerB;
    if (!current.playing) return;
    final dur = current.duration; final pos = current.position;
    if (dur == null) return;
    final remaining = dur - pos;
    String curPath = queuePaths[autoMixIndex.clamp(0, queuePaths.length - 1)];
    final silence = silenceMap[curPath]?? 5.0;
    final triggerSecs = 10 + silence;
    if (remaining.inSeconds <= triggerSecs && remaining.inSeconds > 0) {
      startBlend(current);
    }
  }

  Future<void> startBlend(AudioPlayer current) async {
    isBlending = true;
    AudioPlayer next = (current == playerA)? playerB : playerA;
    autoMixIndex = (autoMixIndex + 1) % queuePaths.length;
    String p = queuePaths[autoMixIndex]; String n = queueNames[autoMixIndex];
    await next.setFilePath(p);
    if (next == playerA) { setState(()=> nameA = n); } else { setState(()=> nameB = n); }
    if (next == playerA) { cross = 1.0; } else { cross = 0.0; }
    updateVol(); next.play();
    bool fadeToB = (next == playerB);
    for (int i = 0; i <= 20; i++) {
      if (!mounted ||!autoMix) break;
      await Future.delayed(const Duration(milliseconds: 500));
      setState(()=> cross = fadeToB? i/20 : 1 - i/20);
      updateVol();
    }
    await current.stop();
    isBlending = false;
  }

  Future<void> load(bool isA, [String? qPath, String? qName]) async {
    String? p = qPath; String? n = qName;
    if (p == null) {
      var r = await FilePicker.platform.pickFiles(type: FileType.audio);
      if (r == null) return; p = r.files.single.path; n = r.files.single.name;
    }
    if (p == null) return;
    if (isA) { await playerA.setFilePath(p); setState(()=> nameA = n); }
    else { await playerB.setFilePath(p); setState(()=> nameB = n); }
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
    // Analyze trailing silence in background
    for (var p in queuePaths) {
      if (!silenceMap.containsKey(p)) {
        detectTrailingSilence(p).then((s) {
          if (mounted) setState(() => silenceMap[p] = s);
        });
      }
    }
  }

  Future<void> startQueueAuto() async {
    if (queuePaths.isEmpty) return;
    autoMixIndex = 0; isBlending = false;
    await playerA.setFilePath(queuePaths[0]);
    await playerB.stop();
    setState(()=> { nameA = queueNames[0], nameB = null, cross = 0.0, autoMix = true });
    updateVol(); playerA.play();
  }

  String fmt(Duration d) {
    String two(int n) => n.toString().padLeft(2,'0');
    return "${two(d.inMinutes)}:${two(d.inSeconds%60)}";
  }

  Widget progressBar(AudioPlayer player) {
    return StreamBuilder<Duration>(
      stream: player.positionStream,
      builder: (context, snapPos) {
        final pos = snapPos.data?? Duration.zero;
        final dur = player.duration?? Duration.zero;
        final maxMs = dur.inMilliseconds.toDouble();
        final posMs = pos.inMilliseconds.toDouble().clamp(0.0, maxMs == 0? 1.0 : maxMs);
        return Column(
          children: [
            Slider(
              value: maxMs == 0? 0 : posMs,
              min: 0,
              max: maxMs == 0? 1 : maxMs,
              onChanged: (v) {
                player.seek(Duration(milliseconds: v.toInt()));
              },
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(fmt(pos), style: const TextStyle(fontSize: 11)),
                Text(fmt(dur), style: const TextStyle(fontSize: 11)),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget buildDeck(bool isA) {
    String? nm = isA? nameA : nameB;
    AudioPlayer pl = isA? playerA : playerB;
    return Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [
      Text(isA? 'DECK A' : 'DECK B', style: const TextStyle(fontWeight: FontWeight.bold)),
      Text(nm?? 'No track', overflow: TextOverflow.ellipsis),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        IconButton(icon: const Icon(Icons.folder_open), onPressed: ()=> load(isA)),
        IconButton(icon: const Icon(Icons.play_arrow), onPressed: ()=> pl.play()),
        IconButton(icon: const Icon(Icons.pause), onPressed: ()=> pl.pause()),
      ]),
      progressBar(pl),
    ])));
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('BlendJam'), actions: [
        IconButton(icon: const Icon(Icons.queue_music), onPressed: addToQueue),
        const Center(child: Text('Auto', style: TextStyle(fontSize:12))),
        Switch(value: autoMix, onChanged: (v){ setState(()=> autoMix=v); if(v && queuePaths.isNotEmpty) startQueueAuto(); }),
      ]),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        buildDeck(true),
        Row(children:[ const Text('A'), Expanded(child: Slider(value: cross, onChanged: (v){ setState(()=> cross=v); updateVol(); })), const Text('B') ]),
        buildDeck(false), const SizedBox(height:12),
        if (queueNames.isEmpty) OutlinedButton.icon(icon: const Icon(Icons.add), label: const Text('Add songs to queue'), onPressed: addToQueue)
        else Card(child: Column(children:[
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children:[
            const Padding(padding: EdgeInsets.all(8), child: Text('Up Next')),
            Row(children:[
              TextButton(onPressed: startQueueAuto, child: const Text('Play All Auto')),
              TextButton(onPressed: ()=> setState(()=> {queuePaths.clear(), queueNames.clear(), autoMixIndex=-1}), child: const Text('Clear')),
            ]),
          ]),
          for(int i=0;i<queueNames.length;i++) ListTile(dense:true, title: Text(queueNames[i]),
            subtitle: i==autoMixIndex? const Text('Now playing / blending') : null,
            trailing: Row(mainAxisSize: MainAxisSize.min, children:[
              IconButton(icon: const Icon(Icons.play_arrow), onPressed: ()=> load(true, queuePaths[i], queueNames[i])),
              IconButton(icon: const Icon(Icons.arrow_downward), onPressed: ()=> load(false, queuePaths[i], queueNames[i])),
            ])),
        ])),
      ]),
    );
  }
}
