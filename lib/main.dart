import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:math';

void main() => runApp(const BlendJamApp());

class BlendJamApp extends StatelessWidget {
  const BlendJamApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BlendJam',
      theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: const Color(0xFF0F0F1A)),
      home: const DJPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class DJPage extends StatefulWidget {
  const DJPage({super.key});
  @override State<DJPage> createState() => _DJPageState();
}

class _DJPageState extends State<DJPage> with TickerProviderStateMixin {
  late AudioPlayer playerA, playerB;
  String? fileAName, fileBName;
  double tempoA = 1, tempoB = 1, volA =.8, volB =.8, crossfade =.5;
  List<String> queuePaths = [], queueNames = [];
  bool autoMix = false;
  int autoMixIndex = 0;
  bool isTransitioning = false;
  late AnimationController _waveCtrl;

  @override
  void initState() {
    super.initState();
    playerA = AudioPlayer();
    playerB = AudioPlayer();
    _waveCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat();
    _updateVolumes();
    playerA.positionStream.listen((_) => _autoMixCheck());
  }

  @override
  void dispose() {
    playerA.dispose(); playerB.dispose(); _waveCtrl.dispose();
    super.dispose();
  }

  void _updateVolumes() {
    double a = volA * (1 - crossfade) * 2;
    double b = volB * crossfade * 2;
    if (a > 1) a = 1;
    if (b > 1) b = 1;
    playerA.setVolume(a);
    playerB.setVolume(b);
  }

  Future<void> _loadToDeck(bool isA) async {
    int? sel;
    if (queuePaths.isNotEmpty) {
      sel = await showDialog<int>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E2E),
          title: const Text('Pick a song from queue'),
          content: SizedBox(
            width: double.maxFinite, height: 320,
            child: ListView.builder(
              itemCount: queueNames.length + 1,
              itemBuilder: (c, i) {
                if (i == queueNames.length) {
                  return ListTile(
                    leading: const Icon(Icons.folder_open, color: Colors.purpleAccent),
                    title: const Text('Browse files...'),
                    onTap: () => Navigator.pop(c, -1),
                  );
                }
                return ListTile(
                  leading: const Icon(Icons.music_note, color: Colors.grey),
                  title: Text(queueNames[i], overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                  trailing: Text('${i + 1}'),
                  onTap: () => Navigator.pop(c, i),
                );
              },
            ),
          ),
        ),
      );
      if (sel == null) return;
    }
    String? path, name;
    if (sel!= null && sel >= 0) {
      path = queuePaths[sel]; name = queueNames[sel];
    } else {
      var r = await FilePicker.platform.pickFiles(type: FileType.audio);
      if (r == null) return;
      path = r.files.single.path; name = r.files.single.name;
    }
    if (path == null) return;
    try {
      if (isA) {
        await playerA.setFilePath(path); await playerA.setSpeed(tempoA);
        setState(() => fileAName = name);
      } else {
        await playerB.setFilePath(path); await playerB.setSpeed(tempoB);
        setState(() => fileBName = name);
      }
      _updateVolumes();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Loaded $name')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error $e')));
    }
  }

  Future<void> _addToQueue() async {
    var r = await FilePicker.platform.pickFiles(type: FileType.audio, allowMultiple: true);
    if (r == null) return;
    setState(() {
      for (var f in r.files) {
        if (f.path!= null) { queuePaths.add(f.path!); queueNames.add(f.name); }
      }
    });
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Added ${r.files.length} to queue')));
  }

  void _autoMixCheck() async {
    if (!autoMix || isTransitioning || queuePaths.isEmpty) return;
    final dur = playerA.duration;
    final pos = playerA.position;
    if (dur == null) return;
    if (dur - pos < const Duration(seconds: 15)) {
      isTransitioning = true;
      autoMixIndex = (autoMixIndex + 1) % queuePaths.length;
      await playerB.setFilePath(queuePaths[autoMixIndex]);
      await playerB.setSpeed(tempoB);
      setState(() => fileBName = queueNames[autoMixIndex]);
      playerB.play();
      for (int i = 0; i <= 10; i++) {
        await Future.delayed(const Duration(seconds: 1));
        if (!mounted ||!autoMix) break;
        setState(() => crossfade = i / 10);
        _updateVolumes();
      }
      await playerA.stop();
      await playerA.setFilePath(queuePaths[autoMixIndex]);
      await playerA.play();
      setState(() { fileAName = queueNames[autoMixIndex]; crossfade = 0; });
      _updateVolumes();
      isTransitioning = false;
    }
  }

  // Improved waveform - animated, gradient, mirrored
  Widget _waveform(bool isA, bool isPlaying) {
    final color = isA? Colors.deepPurpleAccent : Colors.orangeAccent;
    return AnimatedBuilder(
      animation: _waveCtrl,
      builder: (c, _) {
        return StreamBuilder<Duration>(
          stream: (isA? playerA : playerB).positionStream,
          builder: (c2, snap) {
            final ms = snap.data?.inMilliseconds?? 0;
            final rand = Random(ms ~/ 400 + (isA? 11 : 777));
            return Container(
              height: 64,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: List.generate(40, (i) {
                  double base = 6 + rand.nextDouble() * 28;
                  // add beat pulse when playing
                  double pulse = isPlaying? sin(_waveCtrl.value * 6.28 + i * 0.7) * 6 : 0;
                  double h = (base + pulse).clamp(4, 52);
                  double opacity = 0.35 + (h / 52) * 0.65;
                  return Container(
                    width: 3.2,
                    height: h,
                    margin: const EdgeInsets.symmetric(horizontal: 1.3),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [color.withOpacity(opacity * 0.5), color.withOpacity(opacity)],
                        begin: Alignment.bottomCenter, end: Alignment.topCenter,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            );
          },
        );
      },
    );
  }

  Widget _deck(bool isA) {
    final player = isA? playerA : playerB;
    final name = isA? fileAName : fileBName;
    final tempo = isA? tempoA : tempoB;
    final vol = isA? volA : volB;
    final col = isA? Colors.deepPurple : Colors.orange;
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF1E1E2E), Color(0xFF15151F)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: col.withOpacity(.35)),
        boxShadow: [BoxShadow(color: col.withOpacity(.15), blurRadius: 18, offset: const Offset(0, 6))],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: isA? [Colors.deepPurple, Colors.purpleAccent] : [Colors.orange, Colors.deepOrange])),
            child: Center(child: Text(isA? 'A' : 'B', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white))),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name?? 'No track loaded', style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
            Text(isA? 'DECK A' : 'DECK B', style: TextStyle(color: Colors.grey[500], fontSize: 10, letterSpacing: 3)),
          ])),
          IconButton.filledTonal(icon: const Icon(Icons.folder_open), onPressed: () => _loadToDeck(isA)),
        ]),
        const SizedBox(height: 10),
        StreamBuilder<PlayerState>(
          stream: player.playerStateStream,
          builder: (c, s) {
            final playing = s.data?.playing?? false;
            return _waveform(isA, playing);
          },
        ),
        const SizedBox(height: 8),
        StreamBuilder<Duration?>(
          stream: player.durationStream,
          builder: (c, dsnap) {
            final dur = dsnap.data?? Duration.zero;
            return StreamBuilder<Duration>(
              stream: player.positionStream,
              builder: (c2, psnap) {
                final pos = psnap.data?? Duration.zero;
                String fmt(Duration d) => "${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}";
                return Column(children: [
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(trackHeight: 3, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7)),
                    child: Slider(
                      value: dur.inMilliseconds > 0? pos.inMilliseconds.clamp(0, dur.inMilliseconds).toDouble() : 0,
                      max: dur.inMilliseconds > 0? dur.inMilliseconds.toDouble() : 1,
                      activeColor: col,
                      onChanged: (v) => player.seek(Duration(milliseconds: v.toInt())),
                  ),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text(fmt(pos), style: const TextStyle(color: Colors.grey, fontSize: 11)),
                    Text(fmt(dur), style: const TextStyle(color: Colors.grey, fontSize: 11)),
                  ]),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    IconButton(icon: const Icon(Icons.replay_10), onPressed: () => player.seek(Duration(seconds: pos.inSeconds - 10))),
                    StreamBuilder<PlayerState>(
                      stream: player.playerStateStream,
                      builder: (c3, s) {
                        final playing = s.data?.playing?? false;
                        return Container(
                          decoration: BoxDecoration(shape: BoxShape.circle, color: col, boxShadow: [BoxShadow(color: col.withOpacity(.5), blurRadius: 12)]),
                          child: IconButton(icon: Icon(playing? Icons.pause : Icons.play_arrow, color: Colors.white, size: 28), onPressed: () => playing? player.pause() : player.play()),
                        );
                      },
                    ),
                    IconButton(icon: const Icon(Icons.forward_10), onPressed: () => player.seek(Duration(seconds: pos.inSeconds + 10))),
                  ]),
                ]);
              },
            );
          },
        ),
        const Divider(color: Colors.white10, height: 18),
        Row(children: [
          const Icon(Icons.speed, size: 15, color: Colors.grey),
          const SizedBox(width: 6),
          const Text('Tempo', style: TextStyle(fontSize: 12)),
          Expanded(child: Slider(value: tempo, min:.5, max: 1.5, divisions: 20, label: tempo.toStringAsFixed(2), activeColor: col,
            onChanged: (v) { if (isA) { setState(() => tempoA = v); } else { setState(() => tempoB = v); } player.setSpeed(v); })),
          SizedBox(width: 38, child: Text('${tempo.toStringAsFixed(2)}x', style: const TextStyle(fontSize: 11, color: Colors.grey))),
        ]),
        Row(children: [
          const Icon(Icons.volume_up, size: 15, color: Colors.grey),
          const SizedBox(width: 6),
          const Text('Vol', style: TextStyle(fontSize: 12)),
          Expanded(child: Slider(value: vol, min: 0, max: 1, activeColor: col,
            onChanged: (v) { if (isA) { setState(() => volA = v); } else { setState(() => volB = v); } _updateVolumes(); })),
        ]),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BlendJam', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        backgroundColor: const Color(0xFF1A1A2E),
        actions: [
          IconButton(
            tooltip: 'Add songs to queue',
            icon: Badge(label: Text('${queueNames.length}'), child: const Icon(Icons.queue_music)),
            onPressed: _addToQueue,
          ),
          Container(
            margin: const EdgeInsets.only(right: 10, top: 8, bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: autoMix? Colors.green.withOpacity(.22) : Colors.white10,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: autoMix? Colors.green : Colors.transparent),
            ),
            child: Row(children: [
              Icon(Icons.auto_awesome, size: 14, color: autoMix? Colors.greenAccent : Colors.grey),
              const SizedBox(width: 4),
              const Text('Auto-mix', style: TextStyle(fontSize: 12)),
              Switch(value: autoMix, activeColor: Colors.greenAccent, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onChanged: (v) {
                  setState(() => autoMix = v);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(v? 'Auto-mix ON - will blend every 15s before end' : 'Auto-mix OFF'), duration: const Duration(seconds: 2)));
                }),
            ]),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF0F0F1A), Color(0xFF1A1A2E)], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
        child: ListView(padding: const EdgeInsets.all(12), children: [
          _deck(true),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(color: Colors.white.withOpacity(.06), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)),
            child: Column(children: [
              Row(children: [
                const Text('A', style: TextStyle(fontWeight: FontWeight.bold)),
                Expanded(child: Slider(value: crossfade, activeColor: Colors.purpleAccent, inactiveColor: Colors.orangeAccent,
                  onChanged: (v) { setState(() => crossfade = v); _updateVolumes(); })),
                const Text('B', style: TextStyle(fontWeight: FontWeight.bold)),
              ]),
              if (isTransitioning) const LinearProgressIndicator(minHeight: 2),
            ]),
          ),
          const SizedBox(height: 12),
          _deck(false),
          const SizedBox(height: 14),
          if (queueNames.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white.withOpacity(.04), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Up Next (${queueNames.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  Row(children: [
                    TextButton.icon(icon: const Icon(Icons.add, size: 16), label: const Text('Add'), onPressed: _addToQueue),
                    TextButton(onPressed: () => setState(() { queuePaths.clear(); queueNames.clear(); }), child: const Text('Clear', style: TextStyle(color: Colors.redAccent))),
                  ]),
                ]),
                const Divider(color: Colors.white10),
                for (int i = 0; i < queueNames.length; i++)
                  Dismissible(
                    key: ValueKey(queuePaths[i] + '$i'),
                    direction: DismissDirection.endToStart,
                    background: Container(alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 16), child: const Icon(Icons.delete, color: Colors.red)),
                    onDismissed: (_) => setState(() { queuePaths.removeAt(i); queueNames.removeAt(i); }),
                    child: ListTile(
                      dense: true,
                      leading: Container(width: 28, height: 28, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8)), child: Center(child: Text('${i + 1}', style: const TextStyle(fontSize: 12)))),
                      title: Text(queueNames[i], overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                      subtitle: i == autoMixIndex? const Text('next in auto-mix', style: TextStyle(fontSize: 10, color: Colors.greenAccent)) : null,
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(icon: const Icon(Icons.play_arrow, size: 20), tooltip: 'Play on A', onPressed: () async { autoMixIndex = i; await playerA.setFilePath(queuePaths[i]); playerA.play(); setState(() => fileAName = queueNames[i]); }),
                        IconButton(icon: const Icon(Icons.arrow_upward, size: 16), tooltip: 'Play on B', onPressed: () async { await playerB.setFilePath(queuePaths[i]); playerB.play(); setState(() => fileBName = queueNames[i]); }),
                      ]),
                    ),
                  ),
              ]),
            )
          else
            OutlinedButton.icon(icon: const Icon(Icons.queue_music), label: const Text('Tap + to build your queue - pick multiple songs at once'), onPressed: _addToQueue),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }
}
