import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:file_picker/file_picker.dart';

void main() {
  runApp(const BlendJamApp());
}

class BlendJamApp extends StatelessWidget {
  const BlendJamApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BlendJam',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
      ),
      home: const DJHomePage(),
    );
  }
}

class DJHomePage extends StatefulWidget {
  const DJHomePage({super.key});
  @override
  State<DJHomePage> createState() => _DJHomePageState();
}

class _DJHomePageState extends State<DJHomePage> {
  final AudioPlayer playerA = AudioPlayer();
  final AudioPlayer playerB = AudioPlayer();

  String? fileAName;
  String? fileBName;
  double crossfade = 0.5;
  double tempoA = 1.0;
  double tempoB = 1.0;
  List<String> queuePaths = [];
  List<String> queueNames = [];
  int currentTrackIndex = 0;

  @override
  void initState() {
    super.initState();
    playerA.setVolume(0.5);
    playerB.setVolume(0.5);
  }

  void _updateVolumes() {
    playerA.setVolume(1.0 - crossfade);
    playerB.setVolume(crossfade);
  }

  Future<void> _loadToDeck(bool isDeckA) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: false,
    );

    if (result != null && result.files.single.path != null) {
      String path = result.files.single.path!;
      String name = result.files.single.name;
      try {
        if (isDeckA) {
          await playerA.setFilePath(path);
          await playerA.setSpeed(tempoA);
          setState(() => fileAName = name);
        } else {
          await playerB.setFilePath(path);
          await playerB.setSpeed(tempoB);
          setState(() => fileBName = name);
        }
        _updateVolumes();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Loaded $name to Deck ${isDeckA ? 'A' : 'B'}')),
          );
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _addToQueue() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.audio, allowMultiple: true,
    );
    if (result != null) {
      setState(() {
        for (var f in result.files) {
          if (f.path != null) {
            queuePaths.add(f.path!);
            queueNames.add(f.name);
          }
        }
      });
    }
  }

  Future<void> _playQueueTrack(int index) async {
    if (index < 0 || index >= queuePaths.length) return;
    setState(() => currentTrackIndex = index);
    try {
      await playerA.setFilePath(queuePaths[index]);
      await playerA.setSpeed(tempoA);
      _updateVolumes();
      await playerA.play();
      setState(() => fileAName = queueNames[index]);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Play error: $e')));
    }
  }

  @override
  void dispose() {
    playerA.dispose();
    playerB.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('BlendJam DJ Mixer'), backgroundColor: Colors.deepPurple),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(child: _buildDeck('DECK A', playerA, fileAName, tempoA, true)),
                const SizedBox(width: 12),
                Expanded(child: _buildDeck('DECK B', playerB, fileBName, tempoB, false)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Column(
              children: [
                const Text('CROSSFADER', style: TextStyle(letterSpacing: 2)),
                Slider(value: crossfade, onChanged: (v) => setState(() { crossfade = v; _updateVolumes(); })),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [Text('A ${((1 - crossfade) * 100).toInt()}%'), Text('B ${(crossfade * 100).toInt()}%')]),
              ],
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Queue (${queueNames.length} songs)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ElevatedButton.icon(onPressed: _addToQueue, icon: const Icon(Icons.add), label: const Text('Add MP3s')),
              ],
            ),
          ),
          Expanded(
            child: queueNames.isEmpty
                ? const Center(child: Text('Tap "Add MP3s" to load songs'))
                : ListView.builder(
                    itemCount: queueNames.length,
                    itemBuilder: (context, i) {
                      final isCurrent = i == currentTrackIndex;
                      return ListTile(
                        selected: isCurrent,
                        leading: Icon(isCurrent ? Icons.equalizer : Icons.music_note),
                        title: Text(queueNames[i]),
                        trailing: IconButton(icon: const Icon(Icons.play_arrow), onPressed: () => _playQueueTrack(i)),
                        onTap: () => _playQueueTrack(i),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeck(String label, AudioPlayer player, String? fileName, double tempo, bool isDeckA) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.deepPurple.withOpacity(0.5))),
      child: Column(children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(fileName ?? 'No file loaded', style: const TextStyle(fontSize: 12, color: Colors.grey), overflow: TextOverflow.ellipsis),
        const SizedBox(height: 8),
        ElevatedButton(onPressed: () => _loadToDeck(isDeckA), child: const Text('Load MP3')),
        StreamBuilder<PlayerState>(
          stream: player.playerStateStream,
          builder: (context, snapshot) {
            final playing = snapshot.data?.playing ?? false;
            return IconButton(iconSize: 48,
              icon: Icon(playing ? Icons.pause_circle_filled : Icons.play_circle_fill),
              onPressed: () async {
                if (fileName == null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Load an MP3 first')));
                  return;
                }
                if (playing) { await player.pause(); } else { await player.play(); }
              });
          },
        ),
        const Text('Tempo'),
        Slider(value: tempo, min: 0.8, max: 1.2, divisions: 20,
          label: '${(tempo * 128).toInt()} BPM',
          onChanged: (v) async {
            setState(() { if (isDeckA) tempoA = v; else tempoB = v; });
            await player.setSpeed(v);
          }),
      ]),
    );
  }
}
