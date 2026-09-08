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
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
      ),
      home: const DJPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class DJPage extends StatefulWidget {
  const DJPage({super.key});
  @override
  State<DJPage> createState() => _DJPageState();
}

class _DJPageState extends State<DJPage> {
  late AudioPlayer playerA;
  late AudioPlayer playerB;
  String? fileAName;
  String? fileBName;
  double tempoA = 1.0;
  double tempoB = 1.0;
  double volA = 0.8;
  double volB = 0.8;
  double crossfade = 0.5;

  @override
  void initState() {
    super.initState();
    playerA = AudioPlayer();
    playerB = AudioPlayer();
    _updateVolumes();
  }

  @override
  void dispose() {
    playerA.dispose();
    playerB.dispose();
    super.dispose();
  }

  void _updateVolumes() {
    double a = volA * (1.0 - crossfade) * 2.0;
    double b = volB * crossfade * 2.0;
    if (a > 1.0) a = 1.0;
    if (b > 1.0) b = 1.0;
    playerA.setVolume(a);
    playerB.setVolume(b);
  }

  Future<void> _loadToDeck(bool isA) async {
    FilePickerResult? r = await FilePicker.platform.pickFiles(type: FileType.audio, allowMultiple: false);
    if (r == null) return;
    String? path = r.files.single.path;
    String? name = r.files.single.name;
    if (path == null) return;
    try {
      if (isA) {
        await playerA.setFilePath(path);
        await playerA.setSpeed(tempoA);
        setState(() { fileAName = name; });
      } else {
        await playerB.setFilePath(path);
        await playerB.setSpeed(tempoB);
        setState(() { fileBName = name; });
      }
      _updateVolumes();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Loaded $name')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error $e')));
      }
    }
  }

  Widget _waveform(bool isA) {
    final player = isA ? playerA : playerB;
    return StreamBuilder<Duration>(
      stream: player.positionStream,
      builder: (c, snap) {
        final pos = snap.data?.inMilliseconds ?? 0;
        final rand = Random(pos ~/ 500 + (isA ? 0 : 999));
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(30, (i) {
            final h = 8 + rand.nextDouble() * 32;
            return Container(
              width: 4,
              height: h,
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              decoration: BoxDecoration(
                color: isA ? Colors.deepPurpleAccent : Colors.orangeAccent,
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _deck(bool isA) {
    final player = isA ? playerA : playerB;
    final name = isA ? fileAName : fileBName;
    final tempo = isA ? tempoA : tempoB;
    final vol = isA ? volA : volB;
    return Card(
      color: const Color(0xFF1E1E1E),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: isA ? Colors.deepPurple : Colors.orange,
                  child: Text(isA ? 'A' : 'B'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(name ?? 'No track', style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                ),
                IconButton(icon: const Icon(Icons.folder_open), onPressed: () => _loadToDeck(isA)),
              ],
            ),
            const SizedBox(height: 8),
            _waveform(isA),
            const SizedBox(height: 8),
            StreamBuilder<Duration?>(
              stream: player.durationStream,
              builder: (c, dsnap) {
                final dur = dsnap.data ?? Duration.zero;
                return StreamBuilder<Duration>(
                  stream: player.positionStream,
                  builder: (c2, psnap) {
                    final pos = psnap.data ?? Duration.zero;
                    String fmt(Duration d) {
                      return "${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}";
                    }
                    return Column(
                      children: [
                        Slider(
                          value: dur.inMilliseconds > 0 ? pos.inMilliseconds.clamp(0, dur.inMilliseconds).toDouble() : 0,
                          max: dur.inMilliseconds.toDouble() == 0 ? 1 : dur.inMilliseconds.toDouble(),
                          onChanged: (v) => player.seek(Duration(milliseconds: v.toInt())),
                        ),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(fmt(pos)), Text(fmt(dur))]),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(icon: const Icon(Icons.replay_10), onPressed: () => player.seek(Duration(seconds: pos.inSeconds - 10))),
                            StreamBuilder<PlayerState>(
                              stream: player.playerStateStream,
                              builder: (c3, s) {
                                final playing = s.data?.playing ?? false;
                                return IconButton(
                                  icon: Icon(playing ? Icons.pause_circle_filled : Icons.play_circle_fill, size: 48),
                                  onPressed: () { playing ? player.pause() : player.play(); },
                                );
                              },
                            ),
                            IconButton(icon: const Icon(Icons.forward_10), onPressed: () => player.seek(Duration(seconds: pos.inSeconds + 10))),
                          ],
                        ),
                      ],
                    );
                  },
                );
              },
            ),
            Row(
              children: [
                const Text('Tempo'),
                Expanded(
                  child: Slider(
                    value: tempo,
                    min: 0.5,
                    max: 1.5,
                    divisions: 20,
                    label: tempo.toStringAsFixed(2),
                    onChanged: (v) {
                      setState(() { if (isA) { tempoA = v; } else { tempoB = v; } });
                      player.setSpeed(v);
                    },
                  ),
                ),
              ],
            ),
            Row(
              children: [
                const Text('Vol'),
                Expanded(
                  child: Slider(
                    value: vol,
                    min: 0,
                    max: 1,
                    onChanged: (v) {
                      setState(() { if (isA) { volA = v; } else { volB = v; } });
                      _updateVolumes();
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            _deck(true),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Text('A'),
                    Expanded(
                      child: Slider(
                        value: crossfade,
                        onChanged: (v) { setState(() { crossfade = v; }); _updateVolumes(); },
                      ),
                    ),
                    const Text('B'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            _deck(false),
          ],
        ),
      ),
    );
  }
}
