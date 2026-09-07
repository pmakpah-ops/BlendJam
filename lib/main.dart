import 'package:flutter/material.dart';

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
        primaryColor: Colors.deepPurple,
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
  double crossfade = 0.5;
  double tempoA = 1.0;
  double tempoB = 1.0;
  bool isPlayingA = false;
  bool isPlayingB = false;
  bool autoMix = false;
  int currentTrackIndex = 0;

  final List<String> tracks = List.generate(30, (i) => "Track ${i + 1} - DJ Mix ${i + 1}");

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BlendJam DJ Mixer'),
        backgroundColor: Colors.deepPurple,
        actions: [
          Switch(
            value: autoMix,
            onChanged: (v) => setState(() => autoMix = v),
          ),
          const Padding(
            padding: EdgeInsets.only(right: 12, top: 16),
            child: Text('Auto Mix'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: _buildDeck(
                    'DECK A',
                    isPlayingA,
                    tempoA,
                    (v) => setState(() => tempoA = v),
                    () => setState(() => isPlayingA =!isPlayingA),
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDeck(
                    'DECK B',
                    isPlayingB,
                    tempoB,
                    (v) => setState(() => tempoB = v),
                    () => setState(() => isPlayingB =!isPlayingB),
                    Colors.red,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Column(
              children: [
                const Text('CROSSFADER', style: TextStyle(letterSpacing: 2)),
                Slider(
                  value: crossfade,
                  onChanged: (v) => setState(() => crossfade = v),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('A ${((1 - crossfade) * 100).toInt()}%'),
                    Text('B ${(crossfade * 100).toInt()}%'),
                  ],
                ),
              ],
            ),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text('30 Song Auto DJ Queue', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: tracks.length,
              itemBuilder: (context, i) {
                final isCurrent = i == currentTrackIndex;
                return ListTile(
                  selected: isCurrent,
                  selectedTileColor: Colors.deepPurple.withOpacity(0.3),
                  leading: Icon(
                    isCurrent? Icons.equalizer : Icons.music_note,
                    color: isCurrent? Colors.deepPurpleAccent : null,
                  ),
                  title: Text(tracks[i]),
                  subtitle: Text(autoMix && isCurrent? 'Now Auto-Mixing...' : '128 BPM • 3:45'),
                  trailing: IconButton(
                    icon: const Icon(Icons.play_arrow),
                    onPressed: () => setState(() => currentTrackIndex = i),
                  ),
                  onTap: () => setState(() => currentTrackIndex = i),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        color: Colors.deepPurple,
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.auto_awesome, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              autoMix? 'AUTO MIX ON - Playing ${tracks[currentTrackIndex]}' : 'AUTO MIX OFF',
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeck(String label, bool playing, double tempo, ValueChanged<double> onTempo, VoidCallback onPlay, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.2),
              border: Border.all(color: color),
            ),
            child: Icon(Icons.album, size: 50, color: color),
          ),
          const SizedBox(height: 8),
          IconButton(
            iconSize: 48,
            color: color,
            icon: Icon(playing? Icons.pause_circle_filled : Icons.play_circle_fill),
            onPressed: onPlay,
          ),
          const Text('Tempo'),
          Slider(
            value: tempo,
            min: 0.8,
            max: 1.2,
            divisions: 20,
            label: '${(tempo * 128).toInt()} BPM',
            onChanged: onTempo,
          ),
          Text('${(tempo * 128).toInt()} BPM'),
        ],
      ),
    );
  }
}
