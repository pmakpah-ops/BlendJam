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
  }

  void _autoMixCheck() async {
    if (!autoMix || isTransitioning || queuePaths.isEmpty) return;
    final dur = playerA.duration;
    final pos = playerA
