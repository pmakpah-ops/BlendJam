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
        scaffoldBackgroundColor: const Color(0xFF0F0F1A),
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

class _DJPageState extends State<DJPage> with TickerProviderStateMixin {
  late AudioPlayer playerA;
  late AudioPlayer playerB;
  String? fileAName;
  String? fileBName;
  double tempoA = 1.0;
  double tempoB = 1.0;
  double volA = 0.8;
  double volB = 0.8;
  double crossfade = 0.5;
  List<String> queuePaths = [];
  List<String> queueNames = [];
  bool autoMix = false;
  int autoMixIndex = 0;
  bool isTransitioning = false;
  late AnimationController waveCtrl;

  @override
  void initState() {
    super.initState();
    playerA = AudioPlayer();
    playerB = AudioPlayer();
    waveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
    _updateVolumes();
    playerA.positionStream.listen((_) {
      _autoMixCheck();
    });
  }

  @override
  void dispose() {
    playerA.dispose();
    playerB.dispose();
    waveCtrl.dispose();
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
        builder: (ctx) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1E1E2E),
            title: const Text('Pick from queue'),
            content: SizedBox(
              width: double.maxFinite,
              height: 320,
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
                    leading: const Icon(Icons.music_note),
                    title: Text(queueNames[i], overflow: TextOverflow.ellipsis),
                    onTap: () => Navigator.pop(c, i),
                  );
                },
              ),
            ),
          );
        },
      );
      if (sel == null) return;
    }

    String? path;
    String? name;
    if (sel!= null && sel >= 0) {
      path = queuePaths[sel];
      name = queueNames[sel];
    } else {
      var r = await FilePicker.platform.pickFiles(type: FileType.audio);
      if (r == null) return;
      path = r.files.single.path;
      name = r.files.single.name;
    }
    if (path == null) return;

    try {
      if (isA) {
        await playerA.setFilePath(path);
        await playerA.setSpeed(tempoA);
        setState(() => fileAName = name);
      } else {
        await playerB.setFilePath(path);
        await playerB.setSpeed(tempoB);
        setState(() => fileBName = name);
      }
      _updateVolumes();
    } catch (e) {
      debugPrint('load error $e');
    }
  }

  Future<void> _addToQueue() async {
    var r = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: true,
    );
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

  void _autoMixCheck() async {
    if (!autoMix) return;
    if (isTransitioning) return;
    if (queuePaths.isEmpty) return;
    final dur = playerA.duration;
    if (dur == null) return;
    final pos = playerA.position;
    final remaining = dur - pos;
    if (remaining.inSeconds < 15) {
      isTransitioning = true;
      autoMixIndex = (autoMixIndex + 1) % queuePaths.length;
      try {
        await playerB.setFilePath(queuePaths[autoMixIndex]);
        await playerB.setSpeed(tempoB);
        if (mounted) {
          setState(() {
            fileBName = queueNames[autoMixIndex];
          });
        }
        playerB.play();
        for (int i = 0; i <= 10; i++) {
          await Future.delayed(const Duration(seconds: 1));
          if (!mounted) break;
          if (!autoMix) break;
          setState(() {
            crossfade = i / 10.0;
          });
          _updateVolumes();
        }
        await playerA.stop();
        await playerA.setFilePath(queuePaths[autoMixIndex]);
        await playerA.play();
        if (mounted) {
          setState(() {
            fileAName = queueNames[autoMixIndex];
            crossfade = 0.0;
          });
        }
        _updateVolumes();
      } catch (e) {
        debugPrint('automix error $e');
      }
      isTransitioning = false;
    }
  }

  Widget _waveform(bool isA, bool isPlaying) {
    final color = isA? Colors.deepPurpleAccent : Colors.orangeAccent;
    return AnimatedBuilder(
      animation: waveCtrl,
      builder: (c, _) {
        return StreamBuilder<Duration>(
          stream: isA? playerA.positionStream : playerB.positionStream,
          builder: (c2, snap) {
            final ms = snap.data?.inMilliseconds?? 0;
            final rand = Random(ms ~/ 400 + (isA? 11 : 777));
            return Container(
              height: 64,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(40, (i) {
                  double base = 6 + rand.nextDouble() * 28;
                  double pulse = 0;
                  if (isPlaying) {
                    pulse = sin(waveCtrl.value * 6.28 + i * 0.7) * 6;
                  }
                  double h = (base + pulse).clamp(4, 52);
                  double opacity = 0.35 + (h / 52) * 0.65;
                  return Container(
                    width: 3.2,
                    height: h,
                    margin: const EdgeInsets.symmetric(horizontal: 1.3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      gradient: LinearGradient(
                        colors: [
                          color.withOpacity(opacity * 0.5),
                          color.withOpacity(opacity),
                        ],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      ),
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
